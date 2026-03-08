//! Recorder: 主线程侧的 handle, 将数据发送到 IO 线程

use std::sync::mpsc::{self, SyncSender};
use std::thread::{self, JoinHandle};

use super::types::{RecordConfig, RecordEvent};
use super::writer::RecordWriter;
use crate::simulation::agent::AgentState;

/// 数据记录器
///
/// Simulation 线程持有此 handle, 通过 `tx.send()` 将数据发送给 IO 线程。
pub struct Recorder {
    tx: SyncSender<RecordEvent>,
    io_thread: Option<JoinHandle<()>>,
}

impl Recorder {
    /// 创建 Recorder + 启动 IO 线程
    pub fn new(config: &RecordConfig) -> Result<Self, String> {
        let (tx, rx) = mpsc::sync_channel::<RecordEvent>(4096);

        let writer = RecordWriter::new(&config.output_dir)
            .map_err(|e| format!("Failed to create output dir: {}", e))?;

        let io_thread = thread::spawn(move || {
            writer.run(rx);
        });

        Ok(Self {
            tx,
            io_thread: Some(io_thread),
        })
    }

    /// 记录市场 Tick 快照
    pub fn record_market_tick(
        &self,
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
    ) {
        let _ = self.tx.send(RecordEvent::MarketTick {
            tick,
            price,
            volume,
            buy_volume,
            sell_volume,
            bid1_price,
            bid1_vol,
            ask1_price,
            ask1_vol,
            ma_5,
            ma_20,
            ma_60,
            rsi_14,
            atr_14,
            vwap,
            std_dev,
            order_imbalance,
        });
    }

    /// 记录一笔成交
    pub fn record_trade(
        &self,
        tick: i64,
        maker_id: u32,
        taker_id: u32,
        price: i64,
        amount: i64,
        taker_side: i8,
    ) {
        let _ = self.tx.send(RecordEvent::Trade {
            tick,
            maker_id,
            taker_id,
            price,
            amount,
            taker_side,
        });
    }

    /// 记录所有 Agent 快照 (每 Tick 调用一次)
    pub fn record_agent_snapshots(&self, agents: &[AgentState], tick: i64, market_price: i64) {
        for agent in agents {
            let equity = agent.cash + agent.stock * market_price;
            let avg = agent.avg_cost();
            let unrealized = if agent.stock > 0 {
                agent.stock * (market_price - avg)
            } else {
                0
            };
            let _ = self.tx.send(RecordEvent::AgentSnapshot {
                tick,
                agent_id: agent.id,
                cash: agent.cash,
                stock: agent.stock,
                locked_cash: agent.locked_cash,
                locked_stock: agent.locked_stock,
                equity,
                realized_pnl: agent.realized_pnl,
                unrealized_pnl: unrealized,
                pending_orders: agent.order_book.pending.len() as i64,
            });
        }
    }

    /// 发送结束信号并等待 IO 线程完成
    pub fn finish(mut self) {
        let _ = self.tx.send(RecordEvent::Done);
        if let Some(handle) = self.io_thread.take() {
            let _ = handle.join();
        }
    }
}
