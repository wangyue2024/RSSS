//! 脚本层 API 类型定义
//!
//! 定义 Rhai 可见的所有数据结构：
//! - `MarketState`   — 只读市场快照 (Arc 包装)
//! - `AccountView`   — 只读账户快照 (Copy)
//! - `AgentOrderBook` — 只读订单跟踪 (Arc 包装)
//! - `ActionMailbox`  — 可变决策收集器

use std::collections::VecDeque;
use std::sync::Arc;

// ============================================================================
// MarketState — 只读市场快照
// ============================================================================

/// 每 Tick 由主循环构建一次，`Arc` 包装后注入所有 Agent 的 Scope。
///
/// 注册为 Rhai 类型 `"MarketState"` (实际类型为 `Arc<MarketState>`)，
/// 仅暴露 getter，确保 Rhai 侧无法修改市场数据。
#[derive(Clone, Debug)]
pub struct MarketState {
    // — 时空感知 —
    pub tick: i64,
    pub total_ticks: i64,
    pub trading_enabled: bool,
    pub fee_rate_bps: i64,

    // — 基础行情 —
    pub price: i64,
    pub volume: i64,

    // — 微观结构 —
    pub buy_volume: i64,
    pub sell_volume: i64,

    // — 盘口 (前 5 档, 扁平化避免 Array clone) —
    pub bid_prices: [i64; 5],
    pub bid_volumes: [i64; 5],
    pub ask_prices: [i64; 5],
    pub ask_volumes: [i64; 5],
    pub order_imbalance: i64, // × 10000 → [-10000, 10000]

    // — 预算技术指标 (全 i64 微元) —
    pub ma_5: i64,
    pub ma_20: i64,
    pub ma_60: i64,
    pub high_20: i64,
    pub low_20: i64,
    pub vwap: i64,
    pub std_dev: i64,
    pub atr_14: i64,
    pub rsi_14: i64, // × 100

    // — 历史序列 (仅通过注册函数访问) —
    pub history_prices: Vec<i64>,
    pub history_volumes: Vec<i64>,
}

impl MarketState {
    /// 创建一个用于测试的默认状态
    #[cfg(test)]
    pub fn test_default() -> Self {
        Self {
            tick: 0,
            total_ticks: 1000,
            trading_enabled: true,
            fee_rate_bps: 3,
            price: 100_000_000,
            volume: 1000,
            buy_volume: 600,
            sell_volume: 400,
            bid_prices: [99_900_000, 99_800_000, 99_700_000, 99_600_000, 99_500_000],
            bid_volumes: [100, 200, 300, 400, 500],
            ask_prices: [
                100_100_000,
                100_200_000,
                100_300_000,
                100_400_000,
                100_500_000,
            ],
            ask_volumes: [150, 250, 350, 450, 550],
            order_imbalance: -500,
            ma_5: 100_000_000,
            ma_20: 99_500_000,
            ma_60: 99_000_000,
            high_20: 102_000_000,
            low_20: 98_000_000,
            vwap: 100_100_000,
            std_dev: 500_000,
            atr_14: 800_000,
            rsi_14: 5500,
            history_prices: vec![100_000_000; 10],
            history_volumes: vec![1000; 10],
        }
    }
}

// ============================================================================
// AccountView — 只读账户快照
// ============================================================================

/// 每 Tick 由结算模块算好，Copy 注入 Scope。
/// 48 bytes, Clone = memcpy。
#[derive(Clone, Copy, Debug, Default)]
pub struct AccountView {
    pub cash: i64,
    pub stock: i64,
    pub total_equity: i64,
    pub avg_cost: i64,
    pub unrealized_pnl: i64,
    pub realized_pnl: i64,
}

// ============================================================================
// AgentOrderBook — 订单跟踪
// ============================================================================

/// 每 Agent 一份, `Arc` 包装零拷贝注入 Scope。
/// Simulation 层 Execution 阶段更新 pending / last_fills / history。
#[derive(Clone, Debug, Default)]
pub struct AgentOrderBook {
    pub pending: Vec<PendingOrder>,
    pub last_fills: Vec<FillReport>, // 暂时保持不变，或者改成 VecDeque
    pub history: VecDeque<HistoricalOrder>, // 改为 VecDeque 提升删除老数据的性能
}

/// 当前活跃挂单
#[derive(Clone, Copy, Debug)]
pub struct PendingOrder {
    pub order_id: i64,
    pub side: i64,      // 1 = buy, -1 = sell
    pub price: i64,     // 微元
    pub amount: i64,    // 原始总挂单量
    pub remaining: i64, // 剩余量
    pub placed_tick: i64,
}

/// 成交回报 (上一 Tick)
#[derive(Clone, Copy, Debug)]
pub struct FillReport {
    pub order_id: i64,
    pub fill_price: i64,
    pub fill_amount: i64,
    pub side: i64,
}

/// 历史已完结订单
#[derive(Clone, Copy, Debug)]
pub struct HistoricalOrder {
    pub order_id: i64,
    pub side: i64,
    pub price: i64,
    pub amount: i64, // 原始下单量
    pub filled: i64, // 实际成交量
    pub status: i64, // 0=fully_filled, 1=cancelled, 2=rejected
    pub placed_tick: i64,
    pub closed_tick: i64,
}

// ============================================================================
// ActionMailbox — 决策收集器
// ============================================================================

/// 每 Tick 注入一个空的 Mailbox，脚本调用方法填充，Tick 结束取回。
/// `submit_*` 函数返回 `order_id`，Agent 可保存以便后续撤单。
#[derive(Clone, Debug)]
pub struct ActionMailbox {
    pub actions: Vec<AgentAction>,
    agent_id: u32,
    counter: u32,
}

/// Agent 决策动作
#[derive(Clone, Debug, PartialEq)]
pub enum AgentAction {
    LimitBuy {
        order_id: i64,
        price: i64,
        amount: i64,
    },
    LimitSell {
        order_id: i64,
        price: i64,
        amount: i64,
    },
    MarketBuy {
        order_id: i64,
        amount: i64,
    },
    MarketSell {
        order_id: i64,
        amount: i64,
    },
    Cancel {
        order_id: i64,
    },
}

impl ActionMailbox {
    /// 创建新的空 Mailbox
    pub fn new(agent_id: u32) -> Self {
        Self {
            actions: Vec::new(),
            agent_id,
            counter: 0,
        }
    }

    /// 生成全局唯一 order_id: (agent_id << 32) | counter
    fn next_id(&mut self) -> i64 {
        self.counter += 1;
        ((self.agent_id as i64) << 32) | (self.counter as i64)
    }

    /// 限价买入，返回 order_id
    pub fn submit_limit_buy(&mut self, price: i64, amount: i64) -> i64 {
        let id = self.next_id();
        self.actions.push(AgentAction::LimitBuy {
            order_id: id,
            price,
            amount,
        });
        id
    }

    /// 限价卖出，返回 order_id
    pub fn submit_limit_sell(&mut self, price: i64, amount: i64) -> i64 {
        let id = self.next_id();
        self.actions.push(AgentAction::LimitSell {
            order_id: id,
            price,
            amount,
        });
        id
    }

    /// 市价买入，返回 order_id
    pub fn submit_market_buy(&mut self, amount: i64) -> i64 {
        let id = self.next_id();
        self.actions.push(AgentAction::MarketBuy {
            order_id: id,
            amount,
        });
        id
    }

    /// 市价卖出，返回 order_id
    pub fn submit_market_sell(&mut self, amount: i64) -> i64 {
        let id = self.next_id();
        self.actions.push(AgentAction::MarketSell {
            order_id: id,
            amount,
        });
        id
    }

    /// 撤单
    pub fn submit_cancel(&mut self, order_id: i64) {
        self.actions.push(AgentAction::Cancel { order_id });
    }
}

// ============================================================================
// Rhai 类型注册
// ============================================================================

/// 向 Rhai Engine 注册所有 scripting 层的类型和 getter/方法。
pub fn register_all(engine: &mut rhai::Engine) {
    register_market_state(engine);
    register_account_view(engine);
    register_agent_order_book(engine);
    register_action_mailbox(engine);
}

/// 注册 Arc<MarketState> getter
fn register_market_state(engine: &mut rhai::Engine) {
    // 实际存储类型是 Arc<MarketState>
    engine.register_type_with_name::<Arc<MarketState>>("MarketState");

    // 时空感知
    engine.register_get("tick", |s: &mut Arc<MarketState>| s.tick);
    engine.register_get("total_ticks", |s: &mut Arc<MarketState>| s.total_ticks);
    engine.register_get("trading_enabled", |s: &mut Arc<MarketState>| {
        s.trading_enabled
    });
    engine.register_get("fee_rate_bps", |s: &mut Arc<MarketState>| s.fee_rate_bps);

    // 基础行情
    engine.register_get("price", |s: &mut Arc<MarketState>| s.price);
    engine.register_get("volume", |s: &mut Arc<MarketState>| s.volume);

    // 微观结构
    engine.register_get("buy_volume", |s: &mut Arc<MarketState>| s.buy_volume);
    engine.register_get("sell_volume", |s: &mut Arc<MarketState>| s.sell_volume);

    // 盘口 — 扁平化 20 个 getter
    engine.register_get("bid_price_0", |s: &mut Arc<MarketState>| s.bid_prices[0]);
    engine.register_get("bid_price_1", |s: &mut Arc<MarketState>| s.bid_prices[1]);
    engine.register_get("bid_price_2", |s: &mut Arc<MarketState>| s.bid_prices[2]);
    engine.register_get("bid_price_3", |s: &mut Arc<MarketState>| s.bid_prices[3]);
    engine.register_get("bid_price_4", |s: &mut Arc<MarketState>| s.bid_prices[4]);
    engine.register_get("bid_vol_0", |s: &mut Arc<MarketState>| s.bid_volumes[0]);
    engine.register_get("bid_vol_1", |s: &mut Arc<MarketState>| s.bid_volumes[1]);
    engine.register_get("bid_vol_2", |s: &mut Arc<MarketState>| s.bid_volumes[2]);
    engine.register_get("bid_vol_3", |s: &mut Arc<MarketState>| s.bid_volumes[3]);
    engine.register_get("bid_vol_4", |s: &mut Arc<MarketState>| s.bid_volumes[4]);
    engine.register_get("ask_price_0", |s: &mut Arc<MarketState>| s.ask_prices[0]);
    engine.register_get("ask_price_1", |s: &mut Arc<MarketState>| s.ask_prices[1]);
    engine.register_get("ask_price_2", |s: &mut Arc<MarketState>| s.ask_prices[2]);
    engine.register_get("ask_price_3", |s: &mut Arc<MarketState>| s.ask_prices[3]);
    engine.register_get("ask_price_4", |s: &mut Arc<MarketState>| s.ask_prices[4]);
    engine.register_get("ask_vol_0", |s: &mut Arc<MarketState>| s.ask_volumes[0]);
    engine.register_get("ask_vol_1", |s: &mut Arc<MarketState>| s.ask_volumes[1]);
    engine.register_get("ask_vol_2", |s: &mut Arc<MarketState>| s.ask_volumes[2]);
    engine.register_get("ask_vol_3", |s: &mut Arc<MarketState>| s.ask_volumes[3]);
    engine.register_get("ask_vol_4", |s: &mut Arc<MarketState>| s.ask_volumes[4]);

    // 盘口压力
    engine.register_get("order_imbalance", |s: &mut Arc<MarketState>| {
        s.order_imbalance
    });

    // 技术指标
    engine.register_get("ma_5", |s: &mut Arc<MarketState>| s.ma_5);
    engine.register_get("ma_20", |s: &mut Arc<MarketState>| s.ma_20);
    engine.register_get("ma_60", |s: &mut Arc<MarketState>| s.ma_60);
    engine.register_get("high_20", |s: &mut Arc<MarketState>| s.high_20);
    engine.register_get("low_20", |s: &mut Arc<MarketState>| s.low_20);
    engine.register_get("vwap", |s: &mut Arc<MarketState>| s.vwap);
    engine.register_get("std_dev", |s: &mut Arc<MarketState>| s.std_dev);
    engine.register_get("atr_14", |s: &mut Arc<MarketState>| s.atr_14);
    engine.register_get("rsi_14", |s: &mut Arc<MarketState>| s.rsi_14);

    // 历史数据 — 按索引查询函数, 不暴露 Vec getter
    engine.register_fn(
        "history_price",
        |s: &mut Arc<MarketState>, idx: i64| -> i64 {
            s.history_prices.get(idx as usize).copied().unwrap_or(0)
        },
    );
    engine.register_fn(
        "history_volume",
        |s: &mut Arc<MarketState>, idx: i64| -> i64 {
            s.history_volumes.get(idx as usize).copied().unwrap_or(0)
        },
    );
    engine.register_fn("history_len", |s: &mut Arc<MarketState>| -> i64 {
        s.history_prices.len() as i64
    });
}

/// 注册 AccountView getter
fn register_account_view(engine: &mut rhai::Engine) {
    engine.register_type_with_name::<AccountView>("AccountView");
    engine.register_get("cash", |a: &mut AccountView| a.cash);
    engine.register_get("stock", |a: &mut AccountView| a.stock);
    engine.register_get("total_equity", |a: &mut AccountView| a.total_equity);
    engine.register_get("avg_cost", |a: &mut AccountView| a.avg_cost);
    engine.register_get("unrealized_pnl", |a: &mut AccountView| a.unrealized_pnl);
    engine.register_get("realized_pnl", |a: &mut AccountView| a.realized_pnl);
}

/// 注册 Arc<AgentOrderBook> 查询函数
fn register_agent_order_book(engine: &mut rhai::Engine) {
    engine.register_type_with_name::<Arc<AgentOrderBook>>("AgentOrderBook");

    // 当前挂单
    engine.register_fn("pending_count", |ob: &mut Arc<AgentOrderBook>| -> i64 {
        ob.pending.len() as i64
    });
    engine.register_fn(
        "pending_id",
        |ob: &mut Arc<AgentOrderBook>, i: i64| -> i64 {
            ob.pending.get(i as usize).map(|o| o.order_id).unwrap_or(-1)
        },
    );
    engine.register_fn(
        "pending_side",
        |ob: &mut Arc<AgentOrderBook>, i: i64| -> i64 {
            ob.pending.get(i as usize).map(|o| o.side).unwrap_or(0)
        },
    );
    engine.register_fn(
        "pending_price",
        |ob: &mut Arc<AgentOrderBook>, i: i64| -> i64 {
            ob.pending.get(i as usize).map(|o| o.price).unwrap_or(0)
        },
    );
    engine.register_fn(
        "pending_amount",
        |ob: &mut Arc<AgentOrderBook>, i: i64| -> i64 {
            ob.pending.get(i as usize).map(|o| o.amount).unwrap_or(0)
        },
    );
    engine.register_fn(
        "pending_remaining",
        |ob: &mut Arc<AgentOrderBook>, i: i64| -> i64 {
            ob.pending.get(i as usize).map(|o| o.remaining).unwrap_or(0)
        },
    );
    engine.register_fn(
        "pending_placed_tick",
        |ob: &mut Arc<AgentOrderBook>, i: i64| -> i64 {
            ob.pending
                .get(i as usize)
                .map(|o| o.placed_tick)
                .unwrap_or(0)
        },
    );

    // 成交回报
    engine.register_fn("fill_count", |ob: &mut Arc<AgentOrderBook>| -> i64 {
        ob.last_fills.len() as i64
    });
    engine.register_fn("fill_id", |ob: &mut Arc<AgentOrderBook>, i: i64| -> i64 {
        ob.last_fills
            .get(i as usize)
            .map(|f| f.order_id)
            .unwrap_or(-1)
    });
    engine.register_fn(
        "fill_price",
        |ob: &mut Arc<AgentOrderBook>, i: i64| -> i64 {
            ob.last_fills
                .get(i as usize)
                .map(|f| f.fill_price)
                .unwrap_or(0)
        },
    );
    engine.register_fn(
        "fill_amount",
        |ob: &mut Arc<AgentOrderBook>, i: i64| -> i64 {
            ob.last_fills
                .get(i as usize)
                .map(|f| f.fill_amount)
                .unwrap_or(0)
        },
    );
    engine.register_fn("fill_side", |ob: &mut Arc<AgentOrderBook>, i: i64| -> i64 {
        ob.last_fills.get(i as usize).map(|f| f.side).unwrap_or(0)
    });

    // 历史订单
    engine.register_fn(
        "order_history_count",
        |ob: &mut Arc<AgentOrderBook>| -> i64 { ob.history.len() as i64 },
    );
    engine.register_fn(
        "order_history_id",
        |ob: &mut Arc<AgentOrderBook>, i: i64| -> i64 {
            ob.history.get(i as usize).map(|o| o.order_id).unwrap_or(-1)
        },
    );
    engine.register_fn(
        "order_history_status",
        |ob: &mut Arc<AgentOrderBook>, i: i64| -> i64 {
            ob.history.get(i as usize).map(|o| o.status).unwrap_or(-1)
        },
    );
    engine.register_fn(
        "order_history_filled",
        |ob: &mut Arc<AgentOrderBook>, i: i64| -> i64 {
            ob.history.get(i as usize).map(|o| o.filled).unwrap_or(0)
        },
    );
}

/// 注册 ActionMailbox 方法
fn register_action_mailbox(engine: &mut rhai::Engine) {
    engine.register_type_with_name::<ActionMailbox>("ActionMailbox");
    engine.register_fn("submit_limit_buy", ActionMailbox::submit_limit_buy);
    engine.register_fn("submit_limit_sell", ActionMailbox::submit_limit_sell);
    engine.register_fn("submit_market_buy", ActionMailbox::submit_market_buy);
    engine.register_fn("submit_market_sell", ActionMailbox::submit_market_sell);
    engine.register_fn("submit_cancel", ActionMailbox::submit_cancel);
}
