//! Simulation 运行时
//!
//! 系统的 "上帝" — 初始化世界、驱动时间、串联撮合与结算、管理 Agent 生命周期。
//!
//! # 架构
//!
//! ```text
//! ┌─────────────────────────────────────────────────────┐
//! │ World (主循环)                                       │
//! │  ┌─────────┐   ┌──────────┐   ┌────────────────┐   │
//! │  │ Agents  │──▶│OrderBook │──▶│ Settlement     │   │
//! │  │(Rhai)   │   │(Engine)  │   │(cash/stock/pnl)│   │
//! │  └─────────┘   └──────────┘   └────────────────┘   │
//! │       ▲              │                              │
//! │       │         MatchEvent                          │
//! │  MarketState ◀─ Indicators ◀─ price/volume          │
//! └─────────────────────────────────────────────────────┘
//! ```

pub mod agent;
pub mod config;
pub mod indicators;
pub mod settlement;
pub mod world;

#[cfg(test)]
mod tests;

pub use config::SimConfig;
pub use world::World;
