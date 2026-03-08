//! TUI 共享状态: Simulation 线程写入, TUI 线程读取

use std::collections::VecDeque;
use std::sync::{Arc, Mutex};

/// Agent 在 UI 中的一行
#[derive(Debug, Clone)]
pub struct AgentUiRow {
    pub id: u32,
    pub strategy_idx: usize,
    pub cash: i64,
    pub stock: i64,
    pub locked_cash: i64,
    pub locked_stock: i64,
    pub equity: i64,
    pub realized_pnl: i64,
}

/// 最近成交在 UI 中的一行
#[derive(Debug, Clone)]
pub struct TradeUiRow {
    pub tick: i64,
    pub maker_id: u32,
    pub taker_id: u32,
    pub price: i64,
    pub amount: i64,
    pub taker_side: i8,
}

/// TUI 共享状态
#[derive(Clone, Default)]
pub struct UiState {
    pub tick: i64,
    pub total_ticks: i64,
    pub elapsed_secs: f64,
    pub done: bool,

    // Market State
    pub price: i64,
    pub volume: i64,
    pub bid_prices: [i64; 5],
    pub bid_volumes: [i64; 5],
    pub ask_prices: [i64; 5],
    pub ask_volumes: [i64; 5],
    pub ma_5: i64,
    pub ma_20: i64,
    pub rsi_14: i64,

    // Engine Stats
    pub total_orders: u64,
    pub total_trades: u64,
    pub total_cancels: u64,
    pub sim_rejects: u64,

    // Chart Data
    pub price_history: VecDeque<i64>,

    // recent trades (改为 VecDeque 提升插入效率)
    pub recent_trades: VecDeque<TradeUiRow>,

    // Top Agents
    pub agents: Vec<AgentUiRow>,
    pub num_scripts: usize,
}

impl UiState {
    pub fn new(total_ticks: i64, num_scripts: usize) -> Self {
        Self {
            total_ticks,
            num_scripts,
            price_history: VecDeque::with_capacity(200),
            recent_trades: VecDeque::with_capacity(20),
            rsi_14: 5000,
            ..Default::default()
        }
    }
}

pub type SharedUiState = Arc<Mutex<UiState>>;
