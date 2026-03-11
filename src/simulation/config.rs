//! 仿真配置

/// 仿真运行参数
#[derive(Debug, Clone)]
pub struct SimConfig {
    // — 世界参数 —
    pub total_ticks: i64,
    pub warmup_ticks: i64,
    pub initial_price: i64, // 微元
    pub global_seed: u64,

    // — Agent 参数 —
    pub num_agents: u32,
    pub initial_cash: i64, // 微元
    pub initial_stock: i64,

    // — 经济参数 —
    pub fee_rate_bps: i64, // 手续费基点

    // — 引擎参数 —
    pub gc_interval: i64,
    pub gc_threshold: usize,

    // — 历史窗口 —
    pub history_window: usize,
}

impl Default for SimConfig {
    fn default() -> Self {
        Self {
            total_ticks: 100_000,
            warmup_ticks: 100,
            initial_price: 100_000_000, // 100.00 元
            global_seed: 42,
            num_agents: 1000,
            initial_cash: 100_000_000_000, // 100,000 元
            initial_stock: 10,
            fee_rate_bps: 3,
            gc_interval: 500,
            gc_threshold: 10_000,
            history_window: 256,
        }
    }
}
