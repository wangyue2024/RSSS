//! IO 线程: 从 channel 接收事件 → BufWriter CSV 写入

use std::fs::{self, File};
use std::io::{BufWriter, Write};
use std::path::Path;
use std::sync::mpsc::Receiver;

use super::types::RecordEvent;

/// IO 线程端的 CSV 写入器
pub struct RecordWriter {
    market_w: BufWriter<File>,
    trades_w: BufWriter<File>,
    agents_w: BufWriter<File>,
}

impl RecordWriter {
    /// 创建输出目录 + 打开文件 + 写 CSV header
    pub fn new(output_dir: &str) -> std::io::Result<Self> {
        let dir = Path::new(output_dir);
        fs::create_dir_all(dir)?;

        let mut market_w = BufWriter::new(File::create(dir.join("market.csv"))?);
        let mut trades_w = BufWriter::new(File::create(dir.join("trades.csv"))?);
        let mut agents_w = BufWriter::new(File::create(dir.join("agents.csv"))?);

        // 写 CSV header
        writeln!(
            market_w,
            "tick,price,volume,buy_vol,sell_vol,bid1_px,bid1_vol,ask1_px,ask1_vol,ma5,ma20,ma60,rsi14,atr14,vwap,stddev,imbalance"
        )?;
        writeln!(
            trades_w,
            "tick,maker_id,taker_id,price,amount,taker_side"
        )?;
        writeln!(
            agents_w,
            "tick,agent_id,cash,stock,equity,realized_pnl,unrealized_pnl,pending_orders"
        )?;

        Ok(Self {
            market_w,
            trades_w,
            agents_w,
        })
    }

    /// IO 线程主循环: 从 channel 读取事件并写入
    pub fn run(mut self, rx: Receiver<RecordEvent>) {
        while let Ok(event) = rx.recv() {
            match event {
                RecordEvent::MarketTick {
                    tick, price, volume, buy_volume, sell_volume,
                    bid1_price, bid1_vol, ask1_price, ask1_vol,
                    ma_5, ma_20, ma_60, rsi_14, atr_14, vwap, std_dev,
                    order_imbalance,
                } => {
                    let _ = writeln!(
                        self.market_w,
                        "{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}",
                        tick, price, volume, buy_volume, sell_volume,
                        bid1_price, bid1_vol, ask1_price, ask1_vol,
                        ma_5, ma_20, ma_60, rsi_14, atr_14, vwap, std_dev,
                        order_imbalance,
                    );
                }
                RecordEvent::Trade {
                    tick, maker_id, taker_id, price, amount, taker_side,
                } => {
                    let _ = writeln!(
                        self.trades_w,
                        "{},{},{},{},{},{}",
                        tick, maker_id, taker_id, price, amount, taker_side,
                    );
                }
                RecordEvent::AgentSnapshot {
                    tick, agent_id, cash, stock, equity,
                    realized_pnl, unrealized_pnl, pending_orders,
                } => {
                    let _ = writeln!(
                        self.agents_w,
                        "{},{},{},{},{},{},{},{}",
                        tick, agent_id, cash, stock, equity,
                        realized_pnl, unrealized_pnl, pending_orders,
                    );
                }
                RecordEvent::Done => {
                    let _ = self.market_w.flush();
                    let _ = self.trades_w.flush();
                    let _ = self.agents_w.flush();
                    break;
                }
            }
        }
    }
}
