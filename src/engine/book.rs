//! 核心撮合引擎 (OrderBook)
//!
//! 维护买卖盘口，处理下单、撤单、撮合、GC 和 L2 快照。
//!
//! **设计要点**:
//! - BTreeMap 保证价格有序，配合 VecDeque 保证同价位时间优先
//! - HashMap 倒排索引支持 O(1) 影子撤单
//! - raw_pop_front 分离弹出与扣量，防止幽灵订单双重扣减
//! - 所有操作返回 MatchEvent 事件流，引擎不直接修改外部状态

use std::collections::{BTreeMap, HashMap};

use crate::domain::{Order, OrderType, Price, Side, Vol};

use super::events::{MatchEvent, RejectReason};
use super::queue::LevelQueue;

/// L2 行情快照类型: (price, volume) 对的向量
pub type L2Side = Vec<(Price, Vol)>;

// ============================================================================
// OrderMeta — 倒排索引元数据
// ============================================================================

/// 订单倒排索引条目
///
/// 存储挂单时的关键信息，用于 O(1) 影子撤单：
/// - `price` + `side`: 定位 BTreeMap 中的 LevelQueue
/// - `amount`: 撤单时扣减 `total_volume`
/// - `agent_id`: 必要时用于事件生成
#[derive(Debug, Clone, Copy)]
pub struct OrderMeta {
    pub price: Price,
    pub side: Side,
    pub amount: Vol,
    pub agent_id: u32,
}

// ============================================================================
// GcReport — GC 回收报告
// ============================================================================

/// GC 回收报告
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GcReport {
    /// 本次清理的幽灵订单数
    pub cleaned_count: usize,
    /// 清理后的有效订单总数
    pub remaining_orders: usize,
    /// 被移除的空价格档位数
    pub removed_levels: usize,
}

// ============================================================================
// EngineStats — 运行时统计
// ============================================================================

/// 引擎运行时统计
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct EngineStats {
    /// 累计接收的订单总数 (process_order 调用次数)
    pub total_orders: u64,
    /// 累计成交笔数 (Trade 事件数)
    pub total_trades: u64,
    /// 累计成交量 (Trade.amount 求和)
    pub total_trade_volume: Vol,
    /// 累计成功撤单数
    pub total_cancels: u64,
    /// 累计拒绝数 (Rejected 事件数)
    pub total_rejects: u64,
    /// 累计挂单数 (Placed 事件数)
    pub total_placed: u64,
}

// ============================================================================
// OrderBook — 核心
// ============================================================================

/// 撮合引擎核心：双向订单簿
///
/// `bids`: 买盘，BTreeMap 天然升序，取最高买价用 `.last_key_value()`
/// `asks`: 卖盘，BTreeMap 天然升序，取最低卖价用 `.first_key_value()`
pub struct OrderBook {
    /// 买盘 (价格升序存储，遍历时 .rev() 取最高)
    bids: BTreeMap<Price, LevelQueue>,
    /// 卖盘 (价格升序存储，.first() 即最低)
    asks: BTreeMap<Price, LevelQueue>,
    /// 倒排索引: order_id -> OrderMeta
    order_index: HashMap<u64, OrderMeta>,
    /// 运行时统计
    stats: EngineStats,
}

impl OrderBook {
    /// 创建空订单簿
    pub fn new() -> Self {
        Self {
            bids: BTreeMap::new(),
            asks: BTreeMap::new(),
            order_index: HashMap::new(),
            stats: EngineStats::default(),
        }
    }

    /// 带容量预估的创建
    pub fn with_capacity(estimated_orders: usize) -> Self {
        Self {
            bids: BTreeMap::new(),
            asks: BTreeMap::new(),
            order_index: HashMap::with_capacity(estimated_orders),
            stats: EngineStats::default(),
        }
    }

    // ========================================================================
    // 公开 API
    // ========================================================================

    /// 核心入口：处理一个新订单
    ///
    /// 1. 循环尝试与对手盘撮合
    /// 2. 限价单剩余量挂入盘口
    /// 3. 市价单剩余量直接丢弃 (IOC)
    pub fn process_order(&mut self, order: Order) -> Vec<MatchEvent> {
        self.stats.total_orders += 1;
        let mut events = Vec::new();
        let mut taker = order;

        // 撮合循环
        while taker.amount > Vol::ZERO {
            if !self.attempt_match(&mut taker, &mut events) {
                break;
            }
        }

        // 处理剩余量
        if taker.amount > Vol::ZERO {
            match taker.kind {
                OrderType::Limit => {
                    self.post_to_book(taker);
                    self.stats.total_placed += 1;
                    events.push(MatchEvent::Placed {
                        order_id: taker.id,
                        price: taker.price,
                        remaining: taker.amount,
                        side: taker.side,
                    });
                }
                OrderType::Market => {
                    // IOC: 市价单剩余量直接丢弃
                    if events.is_empty() {
                        self.stats.total_rejects += 1;
                        events.push(MatchEvent::Rejected {
                            order_id: taker.id,
                            reason: RejectReason::InsufficientLiquidity,
                        });
                    }
                }
            }
        }

        events
    }

    /// 影子撤单
    ///
    /// O(1) 复杂度：从索引中移除，扣减 total_volume，不操作 VecDeque。
    /// 幽灵订单将在后续撮合时被自动跳过，或由 GC 批量清理。
    pub fn cancel_order(&mut self, order_id: u64) -> MatchEvent {
        // 1. 从索引移除
        let meta = match self.order_index.remove(&order_id) {
            Some(m) => m,
            None => {
                self.stats.total_rejects += 1;
                return MatchEvent::Rejected {
                    order_id,
                    reason: RejectReason::OrderNotFound,
                };
            }
        };

        // 2. 根据 side 找到对应盘口
        let book = match meta.side {
            Side::Bid => &mut self.bids,
            Side::Ask => &mut self.asks,
        };

        // 3. 扣减 total_volume (不操作 VecDeque)
        if let Some(queue) = book.get_mut(&meta.price) {
            queue.deduct_volume(meta.amount);
        }

        self.stats.total_cancels += 1;
        MatchEvent::Cancelled { order_id }
    }

    /// L2 行情快照
    ///
    /// 返回 (bids_top, asks_top)，各取 `depth` 档。
    /// 复杂度 O(K)，K = depth。
    pub fn get_l2_snapshot(&self, depth: usize) -> (L2Side, L2Side) {
        // 买盘：最高价优先 → 反向遍历
        let bids: Vec<(Price, Vol)> = self
            .bids
            .iter()
            .rev()
            .take(depth)
            .map(|(&price, queue)| (price, queue.total_volume))
            .collect();

        // 卖盘：最低价优先 → 正向遍历
        let asks: Vec<(Price, Vol)> = self
            .asks
            .iter()
            .take(depth)
            .map(|(&price, queue)| (price, queue.total_volume))
            .collect();

        (bids, asks)
    }

    /// GC 回收：批量清理幽灵订单
    ///
    /// 遍历所有 LevelQueue，移除不在 `order_index` 中的订单，
    /// 重算 `total_volume`，清理空档位。
    ///
    /// 建议在撮合空闲期或 `phantom_count()` 超过阈值时调用。
    pub fn gc_phantom_orders(&mut self) -> GcReport {
        let mut cleaned_count = 0usize;
        let mut removed_levels = 0usize;

        // 处理买盘
        cleaned_count += Self::gc_side(&mut self.bids, &self.order_index, &mut removed_levels);
        // 处理卖盘
        cleaned_count += Self::gc_side(&mut self.asks, &self.order_index, &mut removed_levels);

        GcReport {
            cleaned_count,
            remaining_orders: self.order_index.len(),
            removed_levels,
        }
    }

    /// 快速统计幽灵订单数
    ///
    /// = 所有 LevelQueue 中 orders.len() 总和 - order_index.len()
    pub fn phantom_count(&self) -> usize {
        let total_in_queues: usize = self
            .bids
            .values()
            .chain(self.asks.values())
            .map(|q| q.len())
            .sum();
        // 如果有 bug 导致 index 比 queue 里的多，防止下溢
        total_in_queues.saturating_sub(self.order_index.len())
    }

    /// 当前有效订单总数
    pub fn order_count(&self) -> usize {
        self.order_index.len()
    }

    /// 获取引擎统计信息
    pub fn stats(&self) -> &EngineStats {
        &self.stats
    }

    /// 获取最优买价 (Best Bid)
    pub fn best_bid(&self) -> Option<Price> {
        self.bids.keys().next_back().copied()
    }

    /// 获取最优卖价 (Best Ask)
    pub fn best_ask(&self) -> Option<Price> {
        self.asks.keys().next().copied()
    }

    // ========================================================================
    // 私有方法
    // ========================================================================

    /// 挂单：将订单插入盘口和索引
    fn post_to_book(&mut self, order: Order) {
        // 插入倒排索引
        self.order_index.insert(
            order.id,
            OrderMeta {
                price: order.price,
                side: order.side,
                amount: order.amount,
                agent_id: order.agent_id,
            },
        );

        // 插入对应盘口的价格档位
        let book = match order.side {
            Side::Bid => &mut self.bids,
            Side::Ask => &mut self.asks,
        };
        book.entry(order.price)
            .or_insert_with(LevelQueue::new)
            .push_back(order);
    }

    /// 尝试一次撮合
    ///
    /// 从对手盘的最优档位取出 Maker，与 Taker 匹配。
    /// 返回 `true` 表示本次成功撮合，可继续尝试。
    /// 返回 `false` 表示无法继续（无对手盘或价格不交叉）。
    fn attempt_match(&mut self, taker: &mut Order, events: &mut Vec<MatchEvent>) -> bool {
        // 1. 确定对手盘，取最优价格
        let (opponent_book, best_price) = match taker.side {
            Side::Bid => {
                // 买入 → 找最低卖价
                let price = match self.asks.keys().next().copied() {
                    Some(p) => p,
                    None => return false, // 无卖盘
                };
                (&mut self.asks, price)
            }
            Side::Ask => {
                // 卖出 → 找最高买价
                let price = match self.bids.keys().next_back().copied() {
                    Some(p) => p,
                    None => return false, // 无买盘
                };
                (&mut self.bids, price)
            }
        };

        // 2. 交叉判断 (Cross Check)
        if taker.kind == OrderType::Limit {
            let crossed = match taker.side {
                Side::Bid => taker.price >= best_price, // 买价 >= 最低卖价
                Side::Ask => taker.price <= best_price, // 卖价 <= 最高买价
            };
            if !crossed {
                return false; // 价格未交叉，无法撮合
            }
        }
        // 市价单不做交叉检查，直接吃

        // 3. 从最优档位取出 Maker (跳过幽灵订单)
        let queue = opponent_book.get_mut(&best_price).unwrap();
        let maker = loop {
            match queue.raw_pop_front() {
                Some(order) => {
                    if self.order_index.contains_key(&order.id) {
                        break order; // 有效订单
                    }
                    // 幽灵订单：影子撤单时已扣减 total_volume，直接丢弃
                }
                None => {
                    // 队列里全是幽灵或已空，清理此档位
                    opponent_book.remove(&best_price);
                    return self.attempt_match(taker, events); // 递归尝试下一档位
                }
            }
        };

        // 4. 计算成交量
        let trade_amount = taker.amount.min(maker.amount);

        // 5. 更新 Maker
        //    先从 LevelQueue 扣掉 Maker 的 **全部** 原始挂量，
        //    如果有剩余再 push_front 加回（push_front 内部会 += remaining）。
        let queue = opponent_book.get_mut(&best_price).unwrap();
        queue.deduct_volume(maker.amount); // 扣掉整个 Maker

        let maker_remaining = maker.amount - trade_amount;
        if maker_remaining > Vol::ZERO {
            // Maker 还有剩余：放回队头 (push_front 会加回 remaining 的量)
            let mut remaining_maker = maker;
            remaining_maker.amount = maker_remaining;
            queue.push_front(remaining_maker);
            if let Some(meta) = self.order_index.get_mut(&maker.id) {
                meta.amount = maker_remaining;
            }
        } else {
            // Maker 被完全吃掉：从索引移除
            self.order_index.remove(&maker.id);
            if queue.is_empty() {
                opponent_book.remove(&best_price);
            }
        }

        // 6. 扣减 Taker 的量
        taker.amount -= trade_amount;

        // 7. 生成 Trade 事件 + 统计
        self.stats.total_trades += 1;
        self.stats.total_trade_volume += trade_amount;
        events.push(MatchEvent::Trade {
            maker_order_id: maker.id,
            taker_order_id: taker.id,
            maker_agent_id: maker.agent_id,
            taker_agent_id: taker.agent_id,
            price: best_price,
            amount: trade_amount,
        });

        true
    }

    /// GC 辅助：清理单侧盘口中的幽灵订单
    fn gc_side(
        book: &mut BTreeMap<Price, LevelQueue>,
        index: &HashMap<u64, OrderMeta>,
        removed_levels: &mut usize,
    ) -> usize {
        let mut cleaned = 0usize;
        let mut empty_prices = Vec::new();

        for (&price, queue) in book.iter_mut() {
            let before = queue.len();
            // retain 仅保留索引中存在的订单
            queue.orders.retain(|order| index.contains_key(&order.id));
            cleaned += before - queue.len();

            // 重算 total_volume
            queue.total_volume = queue.orders.iter().fold(Vol::ZERO, |acc, o| acc + o.amount);

            if queue.is_empty() {
                empty_prices.push(price);
            }
        }

        // 清理空档位
        for price in &empty_prices {
            book.remove(price);
        }
        *removed_levels += empty_prices.len();

        cleaned
    }
}

impl Default for OrderBook {
    fn default() -> Self {
        Self::new()
    }
}
