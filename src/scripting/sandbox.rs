//! 安全约束
//!
//! 脚本执行的安全防线：操作次数限制、编译校验。

/// 默认操作次数上限
pub const MAX_OPERATIONS: u64 = 500_000;

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
