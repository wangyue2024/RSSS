//! Record: 异步 IO 线程数据记录模块
//!
//! 通过 mpsc channel 将仿真数据发送给后台 IO 线程，
//! 由 BufWriter 写入 CSV 文件。主线程零阻塞。

pub mod recorder;
pub mod types;
pub mod writer;

pub use recorder::Recorder;
pub use types::RecordConfig;
