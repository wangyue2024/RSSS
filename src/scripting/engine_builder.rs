//! Engine 构建器
//!
//! 构建全局唯一的 `rhai::Engine`，注册所有类型、函数和安全约束。
//! 产物为 `Send + Sync`（因 rhai `sync` feature），可安全地在 Rayon 并行中共享引用。

use rhai::Engine;

use super::api;
use super::math;
use super::rng::AgentRng;
use super::sandbox;

/// 构建完整配置的 Rhai Engine
///
/// 包含：
/// - 所有 API 类型注册 (MarketState, AccountView, OrderBook, Mailbox)
/// - 数学函数 (arr_sum, arr_mean, ..., micros)
/// - AgentRng 随机数
/// - 安全约束 (500K ops 限制)
pub fn build_engine() -> Engine {
    let mut engine = Engine::new();

    // 优化等级：Full (更激进的常量折叠)
    engine.set_optimization_level(rhai::OptimizationLevel::Full);

    // ---- 类型注册 ----
    api::register_all(&mut engine);

    // ---- AgentRng ----
    engine.register_type_with_name::<AgentRng>("AgentRng");
    engine.register_fn("rand_int", AgentRng::rand_int);
    engine.register_fn("rand_bool", AgentRng::rand_bool);

    // ---- 数学函数 (顶层) ----
    engine.register_fn("arr_sum", math::arr_sum);
    engine.register_fn("arr_mean", math::arr_mean);
    engine.register_fn("arr_min", math::arr_min);
    engine.register_fn("arr_max", math::arr_max);
    engine.register_fn("arr_std_dev", math::arr_std_dev);
    engine.register_fn("arr_slope", math::arr_slope);
    engine.register_fn("abs_val", math::abs_val);
    engine.register_fn("clamp_val", math::clamp_val);
    engine.register_fn("micros", math::micros);

    // ---- 安全约束 ----
    sandbox::register_progress_limit(&mut engine, sandbox::MAX_OPERATIONS);

    engine
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_engine_is_send_sync() {
        fn assert_send_sync<T: Send + Sync>() {}
        assert_send_sync::<Engine>();
    }

    #[test]
    fn test_engine_builds_without_panic() {
        let _engine = build_engine();
    }
}
