//! Record: 通过 channel 发送的数据事件类型

/// 数据记录配置
#[derive(Debug, Clone)]
pub struct RecordConfig {
    pub enabled: bool,
    pub output_dir: String,
}

impl Default for RecordConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            output_dir: "output".to_string(),
        }
    }
}

/// 通过 mpsc channel 发送给 IO 线程的事件
pub enum RecordEvent {
    /// 每 Tick 1 条: 市场/指标快照
    MarketTick {
        tick: i64,
        price: i64,
        volume: i64,
        buy_volume: i64,
        sell_volume: i64,
        bid1_price: i64,
        bid1_vol: i64,
        ask1_price: i64,
        ask1_vol: i64,
        ma_5: i64,
        ma_20: i64,
        ma_60: i64,
        rsi_14: i64,
        atr_14: i64,
        vwap: i64,
        std_dev: i64,
        order_imbalance: i64,
    },
    /// 每笔成交 1 条
    Trade {
        tick: i64,
        maker_id: u32,
        taker_id: u32,
        price: i64,
        amount: i64,
        taker_side: i8, // 1=买, -1=卖
    },
    /// 每 Tick × 每 Agent
    AgentSnapshot {
        tick: i64,
        agent_id: u32,
        cash: i64,
        stock: i64,
        equity: i64,
        realized_pnl: i64,
        unrealized_pnl: i64,
        pending_orders: i64,
    },
    /// 仿真结束
    Done,
}
