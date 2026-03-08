//! 撮合引擎领域事件定义
//!
//! `MatchEvent` 是引擎与外部世界通信的唯一媒介。
//! 引擎不直接修改 Agent 状态，仅输出事件流由 Simulation 消费。

use crate::domain::{Price, Side, Vol};

// ============================================================================
// Match Events
// ============================================================================

/// 撮合引擎输出的领域事件
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MatchEvent {
    /// 撮合成交
    ///
    /// 同时携带 Order ID 和 Agent ID，方便外部结算模块
    /// 直接划转资金而无需反查订单归属。
    Trade {
        maker_order_id: u64,
        taker_order_id: u64,
        maker_agent_id: u32,
        taker_agent_id: u32,
        /// 成交价格 (Maker 的挂单价)
        price: Price,
        /// 成交数量
        amount: Vol,
    },
    /// 挂单成功：未能立即成交的限价单进入盘口
    Placed {
        order_id: u64,
        price: Price,
        amount: Vol,    // 原始挂单量
        remaining: Vol, // 剩余挂入盘口的量
        side: Side,
    },
    /// 撤单成功：基于影子撤单机制
    Cancelled { order_id: u64 },
    /// 自我成交拦截：部分撤销挂单量，剩余挂单继续留在盘口
    SelfTradeCancelled {
        maker_order_id: u64,
        taker_order_id: u64,
        consumed: Vol,
    },
    /// 订单被拒绝
    Rejected { order_id: u64, reason: RejectReason },
}

/// 订单拒绝原因
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RejectReason {
    /// 撤单时找不到该订单
    OrderNotFound,
    /// 市价单无对手盘流动性
    InsufficientLiquidity,
    /// 订单因自我成交被取消 (防刷单)
    SelfTrade,
}
