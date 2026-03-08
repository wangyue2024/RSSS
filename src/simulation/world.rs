//! World 全局状态 + 主循环
//!
//! 串联 domain → engine → scripting 三层的 "上帝" 模块。

use std::sync::Arc;

use rand::seq::SliceRandom;
use rand::SeedableRng;
use rand_xoshiro::Xoshiro256PlusPlus;
use rayon::prelude::*;

use crate::domain::{Order, OrderType, Price, Side, Vol};
use crate::engine::{MatchEvent, OrderBook};
use crate::scripting::api::{AgentAction, MarketState};
use crate::scripting::sandbox;

use super::agent::AgentState;
use super::config::SimConfig;
use super::indicators::IndicatorEngine;
use super::settlement::{
    record_sim_rejection, settle_trade, taker_side_from_action, update_order_books_cancelled,
    update_order_books_placed, update_order_books_rejected,
    update_order_books_self_trade_cancelled, update_order_books_trade, validate_action,
};

/// 全局仿真状态
pub struct World {
    pub config: SimConfig,
    pub tick: i64,

    // — 核心组件 —
    pub rhai_engine: rhai::Engine,
    pub order_book: OrderBook,
    pub agents: Vec<AgentState>,
    pub global_rng: Xoshiro256PlusPlus,

    // — 指标 —
    pub indicators: IndicatorEngine,

    // — Tick 聚合 —
    pub tick_volume: i64,
    pub tick_buy_volume: i64,
    pub tick_sell_volume: i64,
    pub tick_vwap_numer: i128,

    // — 统计 —
    pub sim_rejects: u64,

    // — 本 Tick 成交记录 (supply to recorder/TUI) —
    pub last_tick_trades: Vec<(u32, u32, i64, i64, i8)>, // (maker_id, taker_id, price, amount, taker_side)
}

impl World {
    /// 构建完整世界
    pub fn new(config: SimConfig, scripts: Vec<String>) -> Result<Self, String> {
        let rhai_engine = crate::scripting::build_engine();

        // 编译并校验脚本
        let mut compiled: Vec<Arc<rhai::AST>> = Vec::new();
        for (i, src) in scripts.iter().enumerate() {
            let ast = sandbox::compile_and_validate(&rhai_engine, src)
                .map_err(|e| format!("Script {} compile error: {}", i, e))?;
            compiled.push(Arc::new(ast));
        }

        // 创建 Agents
        let mut agents = Vec::with_capacity(config.num_agents as usize);
        for id in 0..config.num_agents {
            let ast_idx = id as usize % compiled.len().max(1);
            let ast = if compiled.is_empty() {
                // 无脚本: 创建空 AST
                Arc::new(rhai_engine.compile("fn on_tick() {}").unwrap())
            } else {
                Arc::clone(&compiled[ast_idx])
            };
            agents.push(AgentState::new(
                id,
                ast,
                config.global_seed,
                config.initial_cash,
                config.initial_stock,
            ));
        }

        let global_rng = Xoshiro256PlusPlus::seed_from_u64(config.global_seed);
        let indicators = IndicatorEngine::new(config.initial_price, config.history_window);

        Ok(Self {
            config,
            tick: 0,
            rhai_engine,
            order_book: OrderBook::new(),
            agents,
            global_rng,
            indicators,
            tick_volume: 0,
            tick_buy_volume: 0,
            tick_sell_volume: 0,
            tick_vwap_numer: 0,
            sim_rejects: 0,
            last_tick_trades: Vec::new(),
        })
    }

    /// 运行全部 Tick
    pub fn run(&mut self) {
        let total = self.config.total_ticks;
        for tick in 0..total {
            self.tick = tick;
            self.run_tick();
        }
    }

    /// 执行单个 Tick (6 阶段)
    pub fn run_tick(&mut self) {
        let tick = self.tick;

        // ═══════════════════════════════════════════
        // Phase 1: Pre-Calculation (主线程)
        // ═══════════════════════════════════════════

        // 1a2. 清空上 Tick 的 trade 记录
        self.last_tick_trades.clear();

        // 1b. 推送上一 Tick 数据到指标引擎
        self.indicators.push(
            self.indicators.last_price(), // 使用 last settled price
            self.tick_volume,
        );

        // 1c. 构建 MarketState
        let market = Arc::new(self.build_market_state());

        // 1d. 重置 Tick 聚合
        self.tick_volume = 0;
        self.tick_buy_volume = 0;
        self.tick_sell_volume = 0;
        self.tick_vwap_numer = 0;

        // ═══════════════════════════════════════════
        // Phase 2: Agent Decision (Rayon 并行)
        // ═══════════════════════════════════════════
        let engine_ref = &self.rhai_engine;

        self.agents.par_iter_mut().for_each(|agent| {
            agent.run_tick(engine_ref, Arc::clone(&market));
        });

        // ═══════════════════════════════════════════
        // Phase 3: Collect Actions (主线程)
        // ═══════════════════════════════════════════
        let mut all_actions: Vec<(u32, AgentAction)> = Vec::new();

        for agent in &mut self.agents {
            let id = agent.id;
            for action in agent.take_actions() {
                all_actions.push((id, action));
            }
        }

        // ═══════════════════════════════════════════
        // Phase 4: Deterministic Shuffle (主线程)
        // ═══════════════════════════════════════════
        all_actions.shuffle(&mut self.global_rng);

        // ═══════════════════════════════════════════
        // Phase 4.5: Clean previous fills before new execution
        // ═══════════════════════════════════════════
        for agent in &mut self.agents {
            Arc::make_mut(&mut agent.order_book).last_fills.clear();
        }

        // ═══════════════════════════════════════════
        // Phase 5: Execution + Settlement (主线程, 串行)
        // ═══════════════════════════════════════════
        let trading_enabled = tick >= self.config.warmup_ticks;

        for (agent_id, action) in &all_actions {
            if !trading_enabled {
                continue;
            }

            // 前置校验
            if !matches!(action, AgentAction::Cancel { .. }) {
                if let Err(_reason) = validate_action(
                    &self.agents[*agent_id as usize],
                    action,
                    self.config.fee_rate_bps,
                    self.indicators.last_price(),
                ) {
                    // 拒绝: 记入 history
                    let oid = match action {
                        AgentAction::LimitBuy { order_id, .. }
                        | AgentAction::LimitSell { order_id, .. }
                        | AgentAction::MarketBuy { order_id, .. }
                        | AgentAction::MarketSell { order_id, .. } => *order_id,
                        _ => 0,
                    };
                    record_sim_rejection(&mut self.agents[*agent_id as usize], oid, tick);
                    self.sim_rejects += 1;
                    continue;
                }
            }

            match action {
                AgentAction::Cancel { order_id } => {
                    let event = self.order_book.cancel_order(*order_id as u64);
                    self.process_event(&event, *agent_id, Side::Bid, tick);
                }
                _ => {
                    if let Some(order) = convert_action(action, *agent_id) {
                        let taker_side = taker_side_from_action(action);
                        let original_amount = order.amount.as_u64() as i64;
                        let original_price = order.price.as_micros();
                        let order_id = order.id as i64;

                        let events = self.order_book.process_order(order);

                        let mut placed = false;
                        let mut filled = 0;

                        for event in &events {
                            match event {
                                MatchEvent::Trade {
                                    taker_order_id,
                                    amount,
                                    ..
                                } => {
                                    if *taker_order_id == order_id as u64 {
                                        filled += amount.as_u64() as i64;
                                    }
                                }
                                MatchEvent::Placed { .. } => {
                                    placed = true;
                                }
                                MatchEvent::SelfTradeCancelled {
                                    consumed,
                                    maker_order_id,
                                    taker_order_id,
                                } => {
                                    // 自成交按规则属于取消，不属于真实成交(filled)。如果需要也可以加在独立字段，由于要求严格生命周期，这里不记为 filled。
                                }
                                _ => {}
                            }
                            self.process_event(event, *agent_id, taker_side, tick);
                        }

                        // 如果订单没有 Placed（全部成交，或市价单全部/部分被拒等，总之一回合结束寿命）
                        if !placed {
                            let status = if filled >= original_amount {
                                0 // fully filled
                            } else if filled > 0 {
                                1 // partially filled (and rejected/cancelled)
                            } else {
                                2 // completely rejected
                            };

                            let agent = &mut self.agents[*agent_id as usize];
                            let book = Arc::make_mut(&mut agent.order_book);

                            // 由于 `process_event` 可能内部调用过 `update_order_books_rejected`，会产生占位空记录。这里清理一下。
                            book.history.retain(|h| h.order_id != order_id);

                            book.history
                                .push_back(crate::scripting::api::HistoricalOrder {
                                    order_id,
                                    side: match taker_side {
                                        Side::Bid => 1,
                                        Side::Ask => -1,
                                    },
                                    price: original_price,
                                    amount: original_amount,
                                    filled,
                                    status,
                                    placed_tick: tick,
                                    closed_tick: tick,
                                });
                            while book.history.len() > 200 {
                                book.history.pop_front();
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════
        // Phase 6: 周期性维护
        // ═══════════════════════════════════════════
        if tick > 0 && tick % self.config.gc_interval == 0 {
            if self.order_book.phantom_count() > self.config.gc_threshold {
                let _ = self.order_book.gc_phantom_orders();
            }
        }
    }

    /// 处理单个 MatchEvent
    fn process_event(
        &mut self,
        event: &MatchEvent,
        taker_agent_id: u32,
        taker_side: Side,
        tick: i64,
    ) {
        match event {
            MatchEvent::Trade {
                maker_order_id,
                taker_order_id,
                maker_agent_id,
                taker_agent_id: _,
                price,
                amount,
            } => {
                // 结算
                settle_trade(
                    &mut self.agents,
                    *maker_agent_id,
                    taker_agent_id,
                    *price,
                    *amount,
                    taker_side,
                    self.config.fee_rate_bps,
                );

                // 更新价格
                self.indicators.set_last_price(price.as_micros());

                // 记录 trade 事件 (maker_id, taker_id, price, amount, taker_side)
                let side_i8: i8 = match taker_side {
                    Side::Bid => 1,
                    Side::Ask => -1,
                };
                self.last_tick_trades.push((
                    *maker_agent_id,
                    taker_agent_id,
                    price.as_micros(),
                    amount.as_u64() as i64,
                    side_i8,
                ));

                // 聚合统计
                let vol = amount.as_u64() as i64;
                self.tick_volume += vol;
                match taker_side {
                    Side::Bid => self.tick_buy_volume += vol,
                    Side::Ask => self.tick_sell_volume += vol,
                }
                self.tick_vwap_numer += price.as_micros() as i128 * vol as i128;

                // 更新 AgentOrderBook
                update_order_books_trade(
                    &mut self.agents,
                    *maker_order_id,
                    *taker_order_id,
                    *maker_agent_id,
                    taker_agent_id,
                    *price,
                    *amount,
                    taker_side,
                    tick,
                );
            }

            MatchEvent::Placed {
                order_id,
                price,
                amount,
                remaining,
                side,
            } => {
                let agent = &mut self.agents[taker_agent_id as usize];
                update_order_books_placed(
                    agent, *order_id, *price, *amount, *remaining, *side, tick,
                );
            }

            MatchEvent::Cancelled { order_id } => {
                update_order_books_cancelled(&mut self.agents, *order_id, tick);
            }

            MatchEvent::SelfTradeCancelled {
                maker_order_id,
                taker_order_id,
                consumed,
            } => {
                update_order_books_self_trade_cancelled(
                    &mut self.agents,
                    *maker_order_id,
                    *taker_order_id,
                    *consumed,
                    tick,
                );
            }

            MatchEvent::Rejected { order_id, .. } => {
                update_order_books_rejected(&mut self.agents, *order_id, tick);
            }
        }
    }

    /// 构建 MarketState
    fn build_market_state(&self) -> MarketState {
        let (bids, asks) = self.order_book.get_l2_snapshot(5);

        let mut bid_prices = [0i64; 5];
        let mut bid_volumes = [0i64; 5];
        let mut ask_prices = [0i64; 5];
        let mut ask_volumes = [0i64; 5];

        for (i, &(price, vol)) in bids.iter().enumerate().take(5) {
            bid_prices[i] = price.as_micros();
            bid_volumes[i] = vol.as_u64() as i64;
        }
        for (i, &(price, vol)) in asks.iter().enumerate().take(5) {
            ask_prices[i] = price.as_micros();
            ask_volumes[i] = vol.as_u64() as i64;
        }

        let bid_total: i64 = bid_volumes.iter().sum();
        let ask_total: i64 = ask_volumes.iter().sum();
        let imbalance = if bid_total + ask_total > 0 {
            ((bid_total - ask_total) as i128 * 10000 / (bid_total + ask_total) as i128) as i64
        } else {
            0
        };

        MarketState {
            tick: self.tick,
            total_ticks: self.config.total_ticks,
            trading_enabled: self.tick >= self.config.warmup_ticks,
            fee_rate_bps: self.config.fee_rate_bps,
            price: self.indicators.last_price(),
            volume: self.tick_volume,
            buy_volume: self.tick_buy_volume,
            sell_volume: self.tick_sell_volume,
            bid_prices,
            bid_volumes,
            ask_prices,
            ask_volumes,
            order_imbalance: imbalance,
            ma_5: self.indicators.ma_5(),
            ma_20: self.indicators.ma_20(),
            ma_60: self.indicators.ma_60(),
            high_20: self.indicators.high_20(),
            low_20: self.indicators.low_20(),
            vwap: self.indicators.vwap(),
            std_dev: self.indicators.std_dev(),
            atr_14: self.indicators.atr_14(),
            rsi_14: self.indicators.rsi_14(),
            history_prices: self.indicators.prices.iter().copied().collect(),
            history_volumes: self.indicators.volumes.iter().copied().collect(),
        }
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// AgentAction → engine::Order 类型转换
fn convert_action(action: &AgentAction, agent_id: u32) -> Option<Order> {
    match action {
        AgentAction::LimitBuy {
            order_id,
            price,
            amount,
        } => Some(Order {
            id: *order_id as u64,
            price: Price(*price),
            amount: Vol(*amount as u64),
            agent_id,
            side: Side::Bid,
            kind: OrderType::Limit,
        }),
        AgentAction::LimitSell {
            order_id,
            price,
            amount,
        } => Some(Order {
            id: *order_id as u64,
            price: Price(*price),
            amount: Vol(*amount as u64),
            agent_id,
            side: Side::Ask,
            kind: OrderType::Limit,
        }),
        AgentAction::MarketBuy { order_id, amount } => Some(Order {
            id: *order_id as u64,
            price: Price(i64::MAX),
            amount: Vol(*amount as u64),
            agent_id,
            side: Side::Bid,
            kind: OrderType::Market,
        }),
        AgentAction::MarketSell { order_id, amount } => Some(Order {
            id: *order_id as u64,
            price: Price(0),
            amount: Vol(*amount as u64),
            agent_id,
            side: Side::Ask,
            kind: OrderType::Market,
        }),
        AgentAction::Cancel { .. } => None,
    }
}
