//! Simulation 模块集成测试

use crate::simulation::{SimConfig, World};

// ========================================================================
// 基本构建测试
// ========================================================================

#[test]
fn test_world_builds() {
    let config = SimConfig {
        num_agents: 3,
        total_ticks: 10,
        warmup_ticks: 0,
        ..Default::default()
    };
    let scripts = vec!["fn on_tick() {}".to_string()];
    let world = World::new(config, scripts);
    assert!(world.is_ok());
}

#[test]
fn test_world_runs_empty_ticks() {
    let config = SimConfig {
        num_agents: 5,
        total_ticks: 20,
        warmup_ticks: 0,
        ..Default::default()
    };
    let scripts = vec!["fn on_tick() {}".to_string()];
    let mut world = World::new(config, scripts).unwrap();
    world.run(); // 不 panic 即可
    assert_eq!(world.tick, 19); // last tick = total - 1
}

// ========================================================================
// 策略执行测试
// ========================================================================

#[test]
fn test_agent_places_order() {
    let config = SimConfig {
        num_agents: 2,
        total_ticks: 3,
        warmup_ticks: 0,
        initial_cash: 10_000_000_000, // 10,000 元
        initial_stock: 100,
        ..Default::default()
    };

    // Agent 0: 买入  Agent 1: 卖出
    let scripts = vec![
        r#"
        fn on_tick() {
            if market.tick == 0 {
                orders.submit_limit_buy(100_000_000, 10);
            }
        }
        "#
        .to_string(),
        r#"
        fn on_tick() {
            if market.tick == 0 {
                orders.submit_limit_sell(99_000_000, 10);
            }
        }
        "#
        .to_string(),
    ];

    let mut world = World::new(config, scripts).unwrap();
    world.run_tick(); // tick 0

    // 验证有订单被处理
    let total_pending: usize = world
        .agents
        .iter()
        .map(|a| a.order_book.pending.len())
        .sum();
    let total_fills: usize = world
        .agents
        .iter()
        .map(|a| a.order_book.last_fills.len())
        .sum();
    let total_history: usize = world
        .agents
        .iter()
        .map(|a| a.order_book.history.len())
        .sum();

    // 至少有一些活动发生
    assert!(
        total_pending + total_fills + total_history > 0,
        "Expected some order activity, got pending={} fills={} history={}",
        total_pending,
        total_fills,
        total_history
    );
}

// ========================================================================
// 校验拒绝测试
// ========================================================================

#[test]
fn test_invalid_order_rejected() {
    let config = SimConfig {
        num_agents: 1,
        total_ticks: 2,
        warmup_ticks: 0,
        initial_cash: 100_000_000, // 仅 100 元
        initial_stock: 0,
        ..Default::default()
    };

    let scripts = vec![r#"
        fn on_tick() {
            // 试图卖出 0 持股 → InsufficientStock
            orders.submit_limit_sell(100_000_000, 10);
        }
        "#
    .to_string()];

    let mut world = World::new(config, scripts).unwrap();
    world.run_tick();

    // 应该被拒绝
    assert!(world.sim_rejects > 0);
    assert_eq!(world.agents[0].order_book.history.len(), 1);
    assert_eq!(world.agents[0].order_book.history[0].status, 2); // rejected
}

// ========================================================================
// 确定性测试
// ========================================================================

#[test]
fn test_deterministic_runs() {
    let make_world = || {
        let config = SimConfig {
            num_agents: 10,
            total_ticks: 50,
            warmup_ticks: 0,
            global_seed: 12345,
            ..Default::default()
        };
        let scripts = vec![r#"
            let counter = 0;
            fn on_tick() {
                counter += 1;
                let r = rand_int(rng, 0, 100);
                if r > 60 {
                    orders.submit_limit_buy(market.price - 100_000, 1);
                }
                if r < 40 {
                    if account.stock > 0 {
                        orders.submit_limit_sell(market.price + 100_000, 1);
                    }
                }
            }
            "#
        .to_string()];
        World::new(config, scripts).unwrap()
    };

    let mut world1 = make_world();
    world1.run();

    let mut world2 = make_world();
    world2.run();

    // 两次运行的 Agent 状态必须完全一致
    for (a1, a2) in world1.agents.iter().zip(world2.agents.iter()) {
        assert_eq!(a1.cash, a2.cash, "Agent {} cash mismatch", a1.id);
        assert_eq!(a1.stock, a2.stock, "Agent {} stock mismatch", a1.id);
        assert_eq!(
            a1.realized_pnl, a2.realized_pnl,
            "Agent {} pnl mismatch",
            a1.id
        );
    }
}

// ========================================================================
// 预热期测试
// ========================================================================

#[test]
fn test_warmup_no_trades() {
    let config = SimConfig {
        num_agents: 2,
        total_ticks: 5,
        warmup_ticks: 5, // 全部是预热期
        ..Default::default()
    };

    let scripts = vec![
        r#"
        fn on_tick() {
            orders.submit_limit_buy(100_000_000, 10);
        }
        "#
        .to_string(),
        r#"
        fn on_tick() {
            orders.submit_limit_sell(99_000_000, 5);
        }
        "#
        .to_string(),
    ];

    let mut world = World::new(config, scripts).unwrap();
    world.run();

    // 预热期不应有任何持仓变动
    for agent in &world.agents {
        assert_eq!(
            agent.cash, 10_000_000_000,
            "Agent {} cash changed during warmup",
            agent.id
        );
        assert_eq!(
            agent.stock, 100,
            "Agent {} stock changed during warmup",
            agent.id
        );
    }
}
