//! 安全约束
//!
//! 脚本执行的安全防线：操作次数限制、编译校验、沙盒试跑。

use std::sync::Arc;

use rhai::{Dynamic, Scope};

use super::api::{AccountView, ActionMailbox, AgentOrderBook, MarketState};
use super::rng::AgentRng;

/// 默认操作次数上限
pub const MAX_OPERATIONS: u64 = 50_000;

/// 向 Engine 注册操作次数限制 (死循环保护)
pub fn register_progress_limit(engine: &mut rhai::Engine, max_ops: u64) {
    engine.on_progress(move |ops| {
        if ops > max_ops {
            Some("Script exceeded operations limit".into())
        } else {
            None
        }
    });
}

/// 编译并校验 Agent 脚本
///
/// 检查：
/// 1. 语法正确 (compile 通过)
/// 2. 必须定义 `fn on_tick()` 函数
///
/// 顶层代码（初始化变量）由 `run_ast_with_scope` 执行，不需要 `fn init()`。
pub fn compile_and_validate(engine: &rhai::Engine, source: &str) -> Result<rhai::AST, String> {
    let ast = engine
        .compile(source)
        .map_err(|e| format!("Compile error: {e}"))?;

    let has_on_tick = ast.iter_functions().any(|f| f.name == "on_tick");
    if !has_on_tick {
        return Err("Missing required function: fn on_tick()".into());
    }

    Ok(ast)
}

/// 沙盒试跑的 tick 数
const DRY_RUN_TICKS: i64 = 10;

/// 沙盒试跑校验
///
/// 用 mock 数据执行顶层初始化 + 多次 `on_tick()`，
/// 捕获运行时错误（类型不匹配、变量未定义、超操作数等）。
/// 多次执行可发现仅在后续 tick 才触发的 bug（如数组长度达阈值后的操作）。
///
/// 必须在 `compile_and_validate` 之后调用。
pub fn dry_run_validate(engine: &rhai::Engine, ast: &rhai::AST) -> Result<(), String> {
    let mut scope = Scope::new();

    // 注入与正式运行一致的 mock 数据
    let market = MarketState::test_default();
    scope.push("market", Arc::new(market));
    scope.push("account", AccountView::default());
    scope.push("my_orders", Arc::new(AgentOrderBook::default()));
    scope.push("orders", ActionMailbox::new(0, 0));
    scope.push("rng", AgentRng::new(42, 0));

    // 执行顶层代码（初始化全局变量）
    engine
        .run_ast_with_scope(&mut scope, ast)
        .map_err(|e| format!("Init error: {e}"))?;

    // 执行多次 on_tick，模拟多 tick 运行
    for tick in 0..DRY_RUN_TICKS {
        let mut m = MarketState::test_default();
        m.tick = tick;
        scope.set_value("market", Arc::new(m));
        scope.set_value("account", AccountView::default());
        scope.set_value("my_orders", Arc::new(AgentOrderBook::default()));
        scope.set_value("orders", ActionMailbox::new(0, 0));

        let _ = engine
            .call_fn::<Dynamic>(&mut scope, ast, "on_tick", ())
            .map_err(|e| format!("on_tick error (tick {tick}): {e}"))?;
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::scripting::engine_builder;

    #[test]
    fn test_valid_script() {
        let engine = engine_builder::build_engine();
        let result = compile_and_validate(
            &engine,
            r#"
            let x = 42;
            fn on_tick() {
                x += 1;
            }
            "#,
        );
        assert!(result.is_ok());
    }

    #[test]
    fn test_missing_on_tick() {
        let engine = engine_builder::build_engine();
        let result = compile_and_validate(&engine, "let x = 1;");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("on_tick"));
    }

    #[test]
    fn test_syntax_error() {
        let engine = engine_builder::build_engine();
        let result = compile_and_validate(&engine, "fn on_tick() { let x = ; }");
        assert!(result.is_err());
    }
}
