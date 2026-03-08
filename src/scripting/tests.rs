//! Scripting 模块集成测试
//!
//! 验证 Rhai Engine 与所有注册类型/函数的端到端行为。

use std::sync::Arc;

use rhai::Scope;

use crate::scripting::api::*;
use crate::scripting::engine_builder;
use crate::scripting::rng::AgentRng;
use crate::scripting::sandbox;

// ========================================================================
// 辅助函数
// ========================================================================

fn make_engine() -> rhai::Engine {
    engine_builder::build_engine()
}

fn make_market() -> Arc<MarketState> {
    Arc::new(MarketState::test_default())
}

fn make_account() -> AccountView {
    AccountView {
        cash: 1_000_000_000_000, // 1,000,000 元
        stock: 500,
        total_equity: 1_050_000_000_000,
        avg_cost: 99_000_000,
        unrealized_pnl: 500_000_000,
        realized_pnl: 0,
    }
}

// ========================================================================
// 基本读取测试
// ========================================================================

#[test]
fn test_read_market_state() {
    let engine = make_engine();
    let ast = engine
        .compile(
            r#"
            fn on_tick() {
                market.price
            }
        "#,
        )
        .unwrap();

    let mut scope = Scope::new();
    scope.push("market", make_market());

    let result = engine
        .call_fn::<i64>(&mut scope, &ast, "on_tick", ())
        .unwrap();
    assert_eq!(result, 100_000_000);
}

#[test]
fn test_read_account_view() {
    let engine = make_engine();
    let ast = engine
        .compile(
            r#"
            fn on_tick() {
                account.stock
            }
        "#,
        )
        .unwrap();

    let mut scope = Scope::new();
    scope.push("account", make_account());

    let result = engine
        .call_fn::<i64>(&mut scope, &ast, "on_tick", ())
        .unwrap();
    assert_eq!(result, 500);
}

#[test]
fn test_read_l2_data() {
    let engine = make_engine();
    let ast = engine
        .compile(
            r#"
            fn on_tick() {
                market.ask_price_0 - market.bid_price_0
            }
        "#,
        )
        .unwrap();

    let mut scope = Scope::new();
    scope.push("market", make_market());

    let result = engine
        .call_fn::<i64>(&mut scope, &ast, "on_tick", ())
        .unwrap();
    assert_eq!(result, 200_000); // 100.10 - 99.90 = 0.20 元
}

#[test]
fn test_history_access() {
    let engine = make_engine();
    let ast = engine
        .compile(
            r#"
            fn on_tick() {
                let len = history_len(market);
                let p0 = history_price(market, 0);
                len * 1000 + p0 / 1_000_000
            }
        "#,
        )
        .unwrap();

    let mut scope = Scope::new();
    scope.push("market", make_market());

    let result = engine
        .call_fn::<i64>(&mut scope, &ast, "on_tick", ())
        .unwrap();
    // len=10, p0=100_000_000 → 10*1000 + 100 = 10100
    assert_eq!(result, 10100);
}

// ========================================================================
// 下单功能测试
// ========================================================================

#[test]
fn test_submit_orders() {
    let engine = make_engine();
    let ast = engine
        .compile(
            r#"
            fn on_tick() {
                let id1 = orders.submit_limit_buy(100_000_000, 50);
                let id2 = orders.submit_limit_sell(101_000_000, 30);
                orders.submit_cancel(id1);
            }
        "#,
        )
        .unwrap();

    let mut scope = Scope::new();
    scope.push("orders", ActionMailbox::new(7));

    let _ = engine.call_fn::<()>(&mut scope, &ast, "on_tick", ());

    let mailbox: ActionMailbox = scope.get_value("orders").unwrap();
    assert_eq!(mailbox.actions.len(), 3);

    // 验证 order_id 编码: agent_id=7, counter=1 → (7 << 32) | 1
    let expected_id1 = (7_i64 << 32) | 1;
    let expected_id2 = (7_i64 << 32) | 2;

    match &mailbox.actions[0] {
        AgentAction::LimitBuy {
            order_id,
            price,
            amount,
        } => {
            assert_eq!(*order_id, expected_id1);
            assert_eq!(*price, 100_000_000);
            assert_eq!(*amount, 50);
        }
        other => panic!("Expected LimitBuy, got {:?}", other),
    }
    match &mailbox.actions[1] {
        AgentAction::LimitSell { order_id, .. } => {
            assert_eq!(*order_id, expected_id2);
        }
        other => panic!("Expected LimitSell, got {:?}", other),
    }
    match &mailbox.actions[2] {
        AgentAction::Cancel { order_id } => {
            assert_eq!(*order_id, expected_id1);
        }
        other => panic!("Expected Cancel, got {:?}", other),
    }
}

// ========================================================================
// Agent 生命周期测试
// ========================================================================

#[test]
fn test_top_level_init_persists() {
    let engine = make_engine();
    let ast = engine
        .compile(
            r#"
            // 顶层代码 = 初始化
            let counter = 0;

            fn on_tick() {
                counter += 1;
                counter
            }
        "#,
        )
        .unwrap();

    let mut scope = Scope::new();

    // 执行顶层代码 (初始化)
    engine.run_ast_with_scope(&mut scope, &ast).unwrap();

    // Tick 1
    scope.set_value("market", make_market());
    let r1 = engine
        .call_fn::<i64>(&mut scope, &ast, "on_tick", ())
        .unwrap();
    assert_eq!(r1, 1);

    // Tick 2
    let r2 = engine
        .call_fn::<i64>(&mut scope, &ast, "on_tick", ())
        .unwrap();
    assert_eq!(r2, 2);

    // Tick 3
    let r3 = engine
        .call_fn::<i64>(&mut scope, &ast, "on_tick", ())
        .unwrap();
    assert_eq!(r3, 3);
}

#[test]
fn test_fn_init_variables_do_not_persist() {
    // 验证 call_fn 的函数局部变量确实不会保留
    let engine = make_engine();
    let ast = engine
        .compile(
            r#"
            fn setup() {
                let x = 42;
            }
            fn on_tick() {
                x  // 这会报错，因为 x 不在 scope 中
            }
        "#,
        )
        .unwrap();

    let mut scope = Scope::new();
    let _ = engine.call_fn::<()>(&mut scope, &ast, "setup", ());
    let result = engine.call_fn::<i64>(&mut scope, &ast, "on_tick", ());
    assert!(result.is_err()); // x 不存在
}

// ========================================================================
// RNG 测试
// ========================================================================

#[test]
fn test_rng_in_script() {
    let engine = make_engine();
    let ast = engine
        .compile(
            r#"
            fn on_tick() {
                rand_int(rng, 0, 100)
            }
        "#,
        )
        .unwrap();

    let mut scope = Scope::new();
    scope.push("rng", AgentRng::new(12345, 0));

    // 收集 10 次结果
    let results: Vec<i64> = (0..10)
        .map(|_| {
            engine
                .call_fn::<i64>(&mut scope, &ast, "on_tick", ())
                .unwrap()
        })
        .collect();

    // 验证确定性: 同种子应产生相同序列
    let mut scope2 = Scope::new();
    scope2.push("rng", AgentRng::new(12345, 0));
    let results2: Vec<i64> = (0..10)
        .map(|_| {
            engine
                .call_fn::<i64>(&mut scope2, &ast, "on_tick", ())
                .unwrap()
        })
        .collect();

    assert_eq!(results, results2);
}

// ========================================================================
// 数学函数在脚本中调用
// ========================================================================

#[test]
fn test_math_in_script() {
    let engine = make_engine();
    let ast = engine
        .compile(
            r#"
            fn on_tick() {
                let arr = [10, 20, 30, 40, 50];
                let m = arr_mean(arr);
                let s = arr_slope(arr);
                m * 1000 + s
            }
        "#,
        )
        .unwrap();

    let mut scope = Scope::new();
    let result = engine
        .call_fn::<i64>(&mut scope, &ast, "on_tick", ())
        .unwrap();
    // mean=30, slope=10 → 30*1000+10 = 30010
    assert_eq!(result, 30010);
}

#[test]
fn test_micros_helper() {
    let engine = make_engine();
    let ast = engine
        .compile(
            r#"
            fn on_tick() {
                micros(100, 500_000)
            }
        "#,
        )
        .unwrap();

    let mut scope = Scope::new();
    let result = engine
        .call_fn::<i64>(&mut scope, &ast, "on_tick", ())
        .unwrap();
    assert_eq!(result, 100_500_000);
}

// ========================================================================
// 订单查询测试
// ========================================================================

#[test]
fn test_order_book_queries() {
    let engine = make_engine();
    let ast = engine
        .compile(
            r#"
            fn on_tick() {
                let n = pending_count(my_orders);
                let fills = fill_count(my_orders);
                n * 1000 + fills
            }
        "#,
        )
        .unwrap();

    let ob = AgentOrderBook {
        pending: vec![
            PendingOrder {
                order_id: 1,
                side: 1,
                price: 100_000_000,
                amount: 50,
                remaining: 50,
                placed_tick: 0,
            },
            PendingOrder {
                order_id: 2,
                side: -1,
                price: 101_000_000,
                amount: 30,
                remaining: 30,
                placed_tick: 1,
            },
        ],
        last_fills: vec![FillReport {
            order_id: 3,
            fill_price: 100_500_000,
            fill_amount: 20,
            side: 1,
        }],
        history: std::collections::VecDeque::new(),
    };

    let mut scope = Scope::new();
    scope.push("my_orders", Arc::new(ob));

    let result = engine
        .call_fn::<i64>(&mut scope, &ast, "on_tick", ())
        .unwrap();
    assert_eq!(result, 2001); // 2 pending * 1000 + 1 fill
}

// ========================================================================
// 安全控制测试
// ========================================================================

#[test]
fn test_ops_limit() {
    let engine = make_engine();
    let ast = engine
        .compile(
            r#"
            fn on_tick() {
                let i = 0;
                while i < 10_000_000 {
                    i += 1;
                }
                i
            }
        "#,
        )
        .unwrap();

    let mut scope = Scope::new();
    let result = engine.call_fn::<i64>(&mut scope, &ast, "on_tick", ());
    assert!(result.is_err()); // 超过 500K ops
}

#[test]
fn test_compile_validation() {
    let engine = make_engine();

    // 有 on_tick → OK
    let ok = sandbox::compile_and_validate(&engine, "let x = 1; fn on_tick() { x += 1; }");
    assert!(ok.is_ok());

    // 没有 on_tick → Error
    let err = sandbox::compile_and_validate(&engine, "let x = 1;");
    assert!(err.is_err());
}

// ========================================================================
// 完整生命周期端到端测试
// ========================================================================

#[test]
fn test_full_agent_lifecycle() {
    let engine = make_engine();

    let script = r#"
            // 顶层初始化
            let trade_count = 0;
            let last_price = 0;

            fn on_tick() {
                // 记录
                trade_count += 1;
                last_price = market.price;

                // 检查成交
                let fills = fill_count(my_orders);

                // 策略: 价格 > ma_20 时买入
                if market.price > market.ma_20 && account.cash > 0 {
                    let id = orders.submit_limit_buy(market.price + 100_000, 10);
                }

                // 返回当前计数
                trade_count
            }
        "#;

    let ast = sandbox::compile_and_validate(&engine, script).unwrap();
    let ast = Arc::new(ast);

    let mut scope = Scope::new();

    // 初始化: 执行顶层代码
    engine.run_ast_with_scope(&mut scope, &ast).unwrap();

    // 模拟 3 个 Tick
    for tick in 0..3 {
        let mut market = MarketState::test_default();
        market.tick = tick;

        scope.set_value("market", Arc::new(market));
        scope.set_value("account", make_account());
        scope.set_value("my_orders", Arc::new(AgentOrderBook::default()));
        scope.set_value("orders", ActionMailbox::new(0));

        let count = engine
            .call_fn::<i64>(&mut scope, &ast, "on_tick", ())
            .unwrap();
        assert_eq!(count, tick + 1);

        // 取回 actions
        let mailbox: ActionMailbox = scope.get_value("orders").unwrap();
        // 因为 test_default 中 price > ma_20 (100M > 99.5M), 每 Tick 都会下单
        assert_eq!(mailbox.actions.len(), 1);
    }
}
