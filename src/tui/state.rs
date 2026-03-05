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
#[derive(Debug, Clone)]
pub struct UiState {
    // — 进度 —
    pub tick: i64,
    pub total_ticks: i64,
    pub elapsed_secs: f64,

    // — 市场 —
    pub price: i64,
    pub volume: i64,
    pub total_trades: u64,
    pub total_orders: u64,
    pub total_cancels: u64,
    pub sim_rejects: u64,

    // — 盘口 (5 档) —
    pub bid_prices: [i64; 5],
    pub bid_volumes: [i64; 5],
    pub ask_prices: [i64; 5],
    pub ask_volumes: [i64; 5],

    // — 指标 —
    pub ma_5: i64,
    pub ma_20: i64,
    pub rsi_14: i64,

    // — 价格历史 (sparkline 用) —
    pub price_history: VecDeque<i64>,

    // — Agent 排行 —
    pub agents: Vec<AgentUiRow>,

    // — 最近成交 —
    pub recent_trades: VecDeque<TradeUiRow>,

    // — 控制 —
    pub done: bool,
    pub num_scripts: usize,
}

impl UiState {
    pub fn new(total_ticks: i64, num_scripts: usize) -> Self {
        Self {
            tick: 0,
            total_ticks,
            elapsed_secs: 0.0,
            price: 0,
            volume: 0,
            total_trades: 0,
            total_orders: 0,
            total_cancels: 0,
            sim_rejects: 0,
            bid_prices: [0; 5],
            bid_volumes: [0; 5],
            ask_prices: [0; 5],
            ask_volumes: [0; 5],
            ma_5: 0,
            ma_20: 0,
            rsi_14: 5000,
            price_history: VecDeque::with_capacity(200),
            agents: Vec::new(),
            recent_trades: VecDeque::with_capacity(20),
            done: false,
            num_scripts,
        }
    }
}

pub type SharedUiState = Arc<Mutex<UiState>>;
