pub mod book;
pub mod events;
pub mod queue;

#[cfg(test)]
mod tests;

// 扁平化导出
pub use book::{EngineStats, GcReport, L2Side, OrderBook, OrderMeta};
pub use events::{MatchEvent, RejectReason};
pub use queue::LevelQueue;
