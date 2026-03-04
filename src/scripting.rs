//! Scripting 接口层
//!
//! Rust-Rhai 零序列化桥梁。
//!
//! - 零浮点: Rhai `no_float` + 全 i64
//! - 零拷贝: `Arc<T>` 包装共享数据
//! - Scope 即 Memory: Agent 变量跨 Tick 保留
//!
//! # 架构
//!
//! ```text
//! 1 个 Engine   (全局, Send+Sync)
//!     ↓
//! N 个 Arc<AST> (策略脚本)
//!     ↓
//! 1000 个 Scope (Agent 私有状态)
//! ```

pub mod api;
pub mod engine_builder;
pub mod math;
pub mod rng;
pub mod sandbox;

#[cfg(test)]
mod tests;

// 扁平化导出: 使用者只需 `use rsss::scripting::*`
pub use api::{
    AccountView, ActionMailbox, AgentAction, AgentOrderBook, FillReport, HistoricalOrder,
    MarketState, PendingOrder,
};
pub use engine_builder::build_engine;
pub use rng::AgentRng;
pub use sandbox::compile_and_validate;
