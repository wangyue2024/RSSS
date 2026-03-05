//! TUI: ratatui 终端实时界面
//!
//! 在 main thread 运行渲染循环, 读取 SharedUiState。

pub mod app;
pub mod state;
pub mod ui;

pub use app::run_tui;
pub use state::{AgentUiRow, SharedUiState, TradeUiRow, UiState};
