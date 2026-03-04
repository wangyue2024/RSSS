//! 结算逻辑
//!
//! 消费 `MatchEvent` → 更新 Agent 经济状态 (cash/stock/pnl) 和订单跟踪。

use crate::domain::{calculate_cost, calculate_fee, Price, Side, Vol};
use crate::scripting::api::{AgentAction, FillReport, HistoricalOrder, PendingOrder};

use super::agent::AgentState;

// ============================================================================
// 前置校验 (订单拒绝制度)
// ============================================================================

/// Simulation 层拒绝原因
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SimRejectReason {
    ZeroAmount,
    InvalidPrice,
    InsufficientStock,
    InsufficientCash,
}

/// 前置校验：订单合法性检查
pub fn validate_action(agent: &AgentState, action: &AgentAction) -> Result<(), SimRejectReason> {
    match action {
        AgentAction::LimitBuy { price, amount, .. } => {
            if *amount <= 0 {
                return Err(SimRejectReason::ZeroAmount);
            }
            if *price <= 0 {
                return Err(SimRejectReason::InvalidPrice);
            }
            // i128 防溢出
            let cost = (*price as i128) * (*amount as i128);
            if cost > agent.cash as i128 {
                return Err(SimRejectReason::InsufficientCash);
            }
            Ok(())
        }
        AgentAction::LimitSell { price, amount, .. } => {
            if *amount <= 0 {
                return Err(SimRejectReason::ZeroAmount);
            }
            if *price <= 0 {
                return Err(SimRejectReason::InvalidPrice);
            }
            if agent.stock < *amount {
                return Err(SimRejectReason::InsufficientStock);
            }
            Ok(())
        }
        AgentAction::MarketBuy { amount, .. } => {
            if *amount <= 0 {
                return Err(SimRejectReason::ZeroAmount);
            }
            if agent.cash <= 0 {
                return Err(SimRejectReason::InsufficientCash);
            }
            Ok(())
        }
        AgentAction::MarketSell { amount, .. } => {
            if *amount <= 0 {
                return Err(SimRejectReason::ZeroAmount);
            }
            if agent.stock < *amount {
                return Err(SimRejectReason::InsufficientStock);
            }
            Ok(())
        }
        AgentAction::Cancel { .. } => Ok(()),
    }
}

// ============================================================================
// Trade 结算
// ============================================================================

/// 结算一笔成交
///
/// 更新 Maker/Taker 的 cash, stock, total_cost, realized_pnl。
/// 双边手续费 (Maker 和 Taker 各付)。
pub fn settle_trade(
    agents: &mut [AgentState],
    maker_id: u32,
    taker_id: u32,
    price: Price,
    amount: Vol,
    taker_side: Side,
    fee_rate_bps: i64,
) {
    let cost = calculate_cost(price, amount);
    let fee = calculate_fee(cost, fee_rate_bps);
    let cost_micros = cost.as_micros();
    let fee_micros = fee.as_micros();
    let vol = amount.as_u64() as i64;

    match taker_side {
        Side::Bid => {
            // Taker 买入, Maker 卖出
            let taker = &mut agents[taker_id as usize];
            taker.cash -= cost_micros + fee_micros;
            taker.stock += vol;
            taker.total_cost += cost_micros;

            let maker = &mut agents[maker_id as usize];
            // Maker 卖出: 实现盈亏
            let avg = maker.avg_cost();
            maker.realized_pnl += (price.as_micros() - avg) * vol;
            maker.cash += cost_micros - fee_micros;
            maker.stock -= vol;
            // 调整持仓成本: 卖出 vol 股, 按均价扣减
            maker.total_cost -= avg * vol;
        }
        Side::Ask => {
            // Taker 卖出, Maker 买入
            let taker = &mut agents[taker_id as usize];
            let avg = taker.avg_cost();
            taker.realized_pnl += (price.as_micros() - avg) * vol;
            taker.cash += cost_micros - fee_micros;
            taker.stock -= vol;
            taker.total_cost -= avg * vol;

            let maker = &mut agents[maker_id as usize];
            maker.cash -= cost_micros + fee_micros;
            maker.stock += vol;
            maker.total_cost += cost_micros;
        }
    }
}

// ============================================================================
// MatchEvent → AgentOrderBook 更新
// ============================================================================

/// 处理 Trade 事件对 AgentOrderBook 的更新
pub fn update_order_books_trade(
    agents: &mut [AgentState],
    maker_order_id: u64,
    taker_order_id: u64,
    maker_agent_id: u32,
    taker_agent_id: u32,
    price: Price,
    amount: Vol,
    taker_side: Side,
    tick: i64,
) {
    let vol = amount.as_u64() as i64;
    let price_micros = price.as_micros();

    // Maker fill 报告
    let fill_maker = FillReport {
        order_id: maker_order_id as i64,
        fill_price: price_micros,
        fill_amount: vol,
        side: match taker_side {
            Side::Bid => -1, // maker 卖
            Side::Ask => 1,  // maker 买
        },
    };

    // Taker fill 报告
    let fill_taker = FillReport {
        order_id: taker_order_id as i64,
        fill_price: price_micros,
        fill_amount: vol,
        side: match taker_side {
            Side::Bid => 1,
            Side::Ask => -1,
        },
    };

    // Maker 侧: pending 更新
    let maker = &mut agents[maker_agent_id as usize];
    maker.order_book.last_fills.push(fill_maker);

    let maker_oid = maker_order_id as i64;
    if let Some(pos) = maker
        .order_book
        .pending
        .iter()
        .position(|p| p.order_id == maker_oid)
    {
        maker.order_book.pending[pos].remaining -= vol;
        if maker.order_book.pending[pos].remaining <= 0 {
            let removed = maker.order_book.pending.swap_remove(pos);
            maker.order_book.history.push(HistoricalOrder {
                order_id: removed.order_id,
                side: removed.side,
                price: removed.price,
                amount: 0,   // 原始量已无法还原, 用 filled 即可
                filled: vol, // 本次成交量 (累计需外部追踪)
                status: 0,   // fully filled
                placed_tick: removed.placed_tick,
                closed_tick: tick,
            });
        }
    }

    // Taker 侧
    let taker = &mut agents[taker_agent_id as usize];
    taker.order_book.last_fills.push(fill_taker);
}

/// 处理 Placed 事件
pub fn update_order_books_placed(
    agent: &mut AgentState,
    order_id: u64,
    price: Price,
    remaining: Vol,
    side: Side,
    tick: i64,
) {
    agent.order_book.pending.push(PendingOrder {
        order_id: order_id as i64,
        side: match side {
            Side::Bid => 1,
            Side::Ask => -1,
        },
        price: price.as_micros(),
        remaining: remaining.as_u64() as i64,
        placed_tick: tick,
    });
}

/// 处理 Cancelled 事件
pub fn update_order_books_cancelled(agents: &mut [AgentState], order_id: u64, tick: i64) {
    let oid = order_id as i64;
    let owner = (oid >> 32) as u32;
    if (owner as usize) >= agents.len() {
        return;
    }
    let agent = &mut agents[owner as usize];
    if let Some(pos) = agent
        .order_book
        .pending
        .iter()
        .position(|p| p.order_id == oid)
    {
        let removed = agent.order_book.pending.swap_remove(pos);
        agent.order_book.history.push(HistoricalOrder {
            order_id: oid,
            side: removed.side,
            price: removed.price,
            amount: removed.remaining,
            filled: 0,
            status: 1, // cancelled
            placed_tick: removed.placed_tick,
            closed_tick: tick,
        });
    }
}

/// 处理 Rejected 事件 (来自引擎)
pub fn update_order_books_rejected(agents: &mut [AgentState], order_id: u64, tick: i64) {
    let oid = order_id as i64;
    let owner = (oid >> 32) as u32;
    if (owner as usize) >= agents.len() {
        return;
    }
    agents[owner as usize]
        .order_book
        .history
        .push(HistoricalOrder {
            order_id: oid,
            side: 0,
            price: 0,
            amount: 0,
            filled: 0,
            status: 2, // rejected
            placed_tick: tick,
            closed_tick: tick,
        });
}

/// Simulation 层拒绝：将非法订单记入 history
pub fn record_sim_rejection(agent: &mut AgentState, order_id: i64, tick: i64) {
    agent.order_book.history.push(HistoricalOrder {
        order_id,
        side: 0,
        price: 0,
        amount: 0,
        filled: 0,
        status: 2, // rejected
        placed_tick: tick,
        closed_tick: tick,
    });
}

// ============================================================================
// 辅助
// ============================================================================

/// 从 AgentAction 推断 taker side
pub fn taker_side_from_action(action: &AgentAction) -> Side {
    match action {
        AgentAction::LimitBuy { .. } | AgentAction::MarketBuy { .. } => Side::Bid,
        AgentAction::LimitSell { .. } | AgentAction::MarketSell { .. } => Side::Ask,
        AgentAction::Cancel { .. } => Side::Bid, // unused for cancel
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Arc;

    fn make_agent(id: u32, cash: i64, stock: i64) -> AgentState {
        let engine = rhai::Engine::new();
        let ast = engine.compile("fn on_tick() {}").unwrap();
        let mut a = AgentState::new(id, Arc::new(ast), 42, cash, stock);
        a.total_cost = stock * 100_000_000; // 假设均价 100.00
        a
    }

    #[test]
    fn test_validate_reject_zero_amount() {
        let agent = make_agent(0, 1_000_000_000, 100);
        let action = AgentAction::LimitBuy {
            order_id: 1,
            price: 100_000_000,
            amount: 0,
        };
        assert_eq!(
            validate_action(&agent, &action),
            Err(SimRejectReason::ZeroAmount)
        );
    }

    #[test]
    fn test_validate_reject_insufficient_stock() {
        let agent = make_agent(0, 1_000_000_000, 10);
        let action = AgentAction::LimitSell {
            order_id: 1,
            price: 100_000_000,
            amount: 50,
        };
        assert_eq!(
            validate_action(&agent, &action),
            Err(SimRejectReason::InsufficientStock)
        );
    }

    #[test]
    fn test_validate_reject_insufficient_cash() {
        let agent = make_agent(0, 100_000_000, 100); // 只有 100 元
        let action = AgentAction::LimitBuy {
            order_id: 1,
            price: 100_000_000, // 100 元
            amount: 10,         // 需要 1000 元
        };
        assert_eq!(
            validate_action(&agent, &action),
            Err(SimRejectReason::InsufficientCash)
        );
    }

    #[test]
    fn test_validate_accept() {
        let agent = make_agent(0, 10_000_000_000, 100);
        let action = AgentAction::LimitBuy {
            order_id: 1,
            price: 100_000_000,
            amount: 10,
        };
        assert!(validate_action(&agent, &action).is_ok());
    }

    #[test]
    fn test_settle_trade_buy() {
        let mut agents = vec![
            make_agent(0, 10_000_000_000, 100), // maker (卖)
            make_agent(1, 10_000_000_000, 0),   // taker (买)
        ];
        agents[1].total_cost = 0;

        settle_trade(
            &mut agents,
            0,                  // maker
            1,                  // taker
            Price(100_000_000), // 100.00 元
            Vol(10),            // 10 股
            Side::Bid,          // taker 买
            3,                  // 万三
        );

        // cost = 100 * 10 = 1000 元 = 1_000_000_000 µ
        // fee = 1_000_000_000 * 3 / 10000 = 300_000 µ = 0.30 元
        assert_eq!(agents[1].stock, 10);
        assert_eq!(agents[1].cash, 10_000_000_000 - 1_000_000_000 - 300_000);
        assert_eq!(agents[0].stock, 90);
        assert_eq!(agents[0].cash, 10_000_000_000 + 1_000_000_000 - 300_000);
    }
}
