//! 撮合引擎单元测试
//!
//! 测试顺序遵循 TDD 推荐：先简后难，逐一击破。

use crate::domain::{Order, OrderType, Price, Side, Vol};
use crate::engine::book::OrderBook;
use crate::engine::events::{MatchEvent, RejectReason};

// ============================================================================
// 测试辅助
// ============================================================================

/// 快速创建限价买单
fn bid(id: u64, price: i64, amount: u64, agent_id: u32) -> Order {
    Order {
        id,
        price: Price(price),
        amount: Vol(amount),
        agent_id,
        side: Side::Bid,
        kind: OrderType::Limit,
    }
}

/// 快速创建限价卖单
fn ask(id: u64, price: i64, amount: u64, agent_id: u32) -> Order {
    Order {
        id,
        price: Price(price),
        amount: Vol(amount),
        agent_id,
        side: Side::Ask,
        kind: OrderType::Limit,
    }
}

/// 快速创建市价买单
fn market_bid(id: u64, amount: u64, agent_id: u32) -> Order {
    Order {
        id,
        price: Price(0), // 市价单价格不用于交叉判断
        amount: Vol(amount),
        agent_id,
        side: Side::Bid,
        kind: OrderType::Market,
    }
}

#[allow(dead_code)]
fn market_ask(id: u64, amount: u64, agent_id: u32) -> Order {
    Order {
        id,
        price: Price(0),
        amount: Vol(amount),
        agent_id,
        side: Side::Ask,
        kind: OrderType::Market,
    }
}

// ============================================================================
// 1. 挂单与 L2 快照
// ============================================================================

#[test]
fn test_post_to_book() {
    let mut book = OrderBook::new();

    // 下两个买单在同一价格
    let events1 = book.process_order(bid(1, 100_000_000, 50, 1));
    assert_eq!(
        events1,
        vec![MatchEvent::Placed {
            order_id: 1,
            price: Price(100_000_000),
            amount: Vol(50),
            remaining: Vol(50),
            side: Side::Bid,
        }]
    );

    let events2 = book.process_order(bid(2, 100_000_000, 30, 2));
    assert_eq!(
        events2,
        vec![MatchEvent::Placed {
            order_id: 2,
            price: Price(100_000_000),
            amount: Vol(30),
            remaining: Vol(30),
            side: Side::Bid,
        }]
    );

    // L2: 一档买盘，聚合量 80
    let (bids, asks) = book.get_l2_snapshot(5);
    assert_eq!(bids.len(), 1);
    assert_eq!(bids[0], (Price(100_000_000), Vol(80)));
    assert_eq!(asks.len(), 0);
}

#[test]
fn test_post_multiple_price_levels() {
    let mut book = OrderBook::new();

    book.process_order(bid(1, 100_000_000, 50, 1));
    book.process_order(bid(2, 99_000_000, 30, 2));
    book.process_order(ask(3, 101_000_000, 20, 3));
    book.process_order(ask(4, 102_000_000, 10, 4));

    let (bids, asks) = book.get_l2_snapshot(5);

    // 买盘：最高价在前
    assert_eq!(bids.len(), 2);
    assert_eq!(bids[0].0, Price(100_000_000)); // 100.00 元 (最高)
    assert_eq!(bids[1].0, Price(99_000_000)); //  99.00 元

    // 卖盘：最低价在前
    assert_eq!(asks.len(), 2);
    assert_eq!(asks[0].0, Price(101_000_000)); // 101.00 元 (最低)
    assert_eq!(asks[1].0, Price(102_000_000)); // 102.00 元
}

// ============================================================================
// 2. 精确撮合 (Exact Match)
// ============================================================================

#[test]
fn test_exact_match() {
    let mut book = OrderBook::new();

    // 买单 100.00 元 50 股
    book.process_order(bid(1, 100_000_000, 50, 1));

    // 卖单 100.00 元 50 股 → 完全成交
    let events = book.process_order(ask(2, 100_000_000, 50, 2));
    assert_eq!(events.len(), 1);
    assert_eq!(
        events[0],
        MatchEvent::Trade {
            maker_order_id: 1,
            taker_order_id: 2,
            maker_agent_id: 1,
            taker_agent_id: 2,
            price: Price(100_000_000), // 以 Maker 价格成交
            amount: Vol(50),
        }
    );

    // L2 全部清空
    let (bids, asks) = book.get_l2_snapshot(5);
    assert!(bids.is_empty());
    assert!(asks.is_empty());
    assert_eq!(book.order_count(), 0);
}

#[test]
fn test_taker_crosses_better_price() {
    let mut book = OrderBook::new();

    // 挂卖单 99.00 元
    book.process_order(ask(1, 99_000_000, 30, 1));

    // 买单 100.00 元 → Taker 愿意出 100 但 Maker 只要 99，以 99 成交
    let events = book.process_order(bid(2, 100_000_000, 30, 2));
    assert_eq!(events.len(), 1);
    match &events[0] {
        MatchEvent::Trade { price, .. } => assert_eq!(*price, Price(99_000_000)),
        _ => panic!("Expected Trade event"),
    }
}

// ============================================================================
// 3. 部分成交 (Partial Match)
// ============================================================================

#[test]
fn test_partial_taker_remaining() {
    let mut book = OrderBook::new();

    // 挂卖单 30 股
    book.process_order(ask(1, 100_000_000, 30, 1));

    // 买单 50 股 → 成交 30, 剩余 20 挂单
    let events = book.process_order(bid(2, 100_000_000, 50, 2));
    assert_eq!(events.len(), 2);
    assert!(matches!(&events[0], MatchEvent::Trade { amount, .. } if *amount == Vol(30)));
    assert!(matches!(
        &events[1],
        MatchEvent::Placed {
            order_id: 2,
            price,
            amount,
            remaining,
            side: Side::Bid,
        } if *price == Price(100_000_000) && *remaining == Vol(20) && *amount == Vol(50)
    ));

    // 验证买盘挂了 20 股
    let (bids, _) = book.get_l2_snapshot(5);
    assert_eq!(bids[0], (Price(100_000_000), Vol(20)));
}

#[test]
fn test_partial_maker_remaining() {
    let mut book = OrderBook::new();

    // 挂卖单 100 股
    book.process_order(ask(1, 100_000_000, 100, 1));

    // 买单 30 股 → 成交 30, Maker 剩余 70
    let events = book.process_order(bid(2, 100_000_000, 30, 2));
    assert_eq!(events.len(), 1);
    assert!(matches!(&events[0], MatchEvent::Trade { amount, .. } if *amount == Vol(30)));

    // 卖盘剩余 70
    let (_, asks) = book.get_l2_snapshot(5);
    assert_eq!(asks[0], (Price(100_000_000), Vol(70)));
}

// ============================================================================
// 4. 时间优先 (Time Priority)
// ============================================================================

#[test]
fn test_time_priority() {
    let mut book = OrderBook::new();

    // A 先挂 100 股, B 后挂 100 股，同价
    book.process_order(ask(1, 100_000_000, 100, 10));
    book.process_order(ask(2, 100_000_000, 100, 20));

    // Taker 买 150 股 → A 全吃 (100), B 吃 50
    let events = book.process_order(bid(3, 100_000_000, 150, 30));

    let trades: Vec<_> = events
        .iter()
        .filter_map(|e| match e {
            MatchEvent::Trade {
                maker_order_id,
                amount,
                ..
            } => Some((*maker_order_id, *amount)),
            _ => None,
        })
        .collect();

    assert_eq!(trades.len(), 2);
    assert_eq!(trades[0], (1, Vol(100))); // A 先全部成交
    assert_eq!(trades[1], (2, Vol(50))); // B 部分成交 50
}

// ============================================================================
// 5. 市价单 (Market Order)
// ============================================================================

#[test]
fn test_market_order_sweep() {
    let mut book = OrderBook::new();

    // 三档卖盘
    book.process_order(ask(1, 100_000_000, 10, 1));
    book.process_order(ask(2, 101_000_000, 10, 2));
    book.process_order(ask(3, 102_000_000, 10, 3));

    // 市价买入 25 股 → 击穿 3 档
    let events = book.process_order(market_bid(4, 25, 4));

    let trades: Vec<_> = events
        .iter()
        .filter_map(|e| match e {
            MatchEvent::Trade { price, amount, .. } => Some((*price, *amount)),
            _ => None,
        })
        .collect();

    assert_eq!(trades.len(), 3);
    assert_eq!(trades[0], (Price(100_000_000), Vol(10))); // 击穿第一档
    assert_eq!(trades[1], (Price(101_000_000), Vol(10))); // 击穿第二档
    assert_eq!(trades[2], (Price(102_000_000), Vol(5))); // 部分吃第三档

    // 验证: 第三档还剩 5 股
    let (_, asks) = book.get_l2_snapshot(5);
    assert_eq!(asks.len(), 1);
    assert_eq!(asks[0], (Price(102_000_000), Vol(5)));
}

#[test]
fn test_market_order_no_liquidity() {
    let mut book = OrderBook::new();

    // 空盘口，市价买入 → Rejected
    let events = book.process_order(market_bid(1, 100, 1));
    assert_eq!(
        events,
        vec![MatchEvent::Rejected {
            order_id: 1,
            reason: RejectReason::InsufficientLiquidity,
        }]
    );
}

#[test]
fn test_market_order_partial_ioc() {
    let mut book = OrderBook::new();

    // 只有 20 股卖单
    book.process_order(ask(1, 100_000_000, 20, 1));

    // 市价买入 50 股 → 成交 20, 剩余 30 直接丢弃 (IOC)
    let events = book.process_order(market_bid(2, 50, 2));

    // 应该有 2 个事件 (1个 Trade, 1个 Rejected)
    assert_eq!(events.len(), 2);
    assert!(matches!(&events[0], MatchEvent::Trade { amount, .. } if *amount == Vol(20)));
    assert!(matches!(
        &events[1],
        MatchEvent::Rejected {
            order_id: 2,
            reason: RejectReason::InsufficientLiquidity
        }
    ));
}

// ============================================================================
// 6. 影子撤单 (Shadow Cancellation)
// ============================================================================

#[test]
fn test_shadow_cancellation() {
    let mut book = OrderBook::new();

    book.process_order(bid(1, 100_000_000, 50, 1));

    // 撤单
    let event = book.cancel_order(1);
    assert_eq!(event, MatchEvent::Cancelled { order_id: 1 });

    // 验证: order_index 已清空
    assert_eq!(book.order_count(), 0);

    // L2: total_volume 已扣减
    let (bids, _) = book.get_l2_snapshot(5);
    // 注意：BTreeMap 中的 key 可能还在，但 total_volume 应为 0
    assert!(bids.is_empty() || bids[0].1 == Vol(0));
}

#[test]
fn test_cancel_nonexistent_order() {
    let mut book = OrderBook::new();

    let event = book.cancel_order(999);
    assert_eq!(
        event,
        MatchEvent::Rejected {
            order_id: 999,
            reason: RejectReason::OrderNotFound,
        }
    );
}

#[test]
fn test_double_cancel() {
    let mut book = OrderBook::new();

    book.process_order(bid(1, 100_000_000, 50, 1));
    assert_eq!(book.cancel_order(1), MatchEvent::Cancelled { order_id: 1 });

    // 第二次撤单应返回 OrderNotFound
    assert_eq!(
        book.cancel_order(1),
        MatchEvent::Rejected {
            order_id: 1,
            reason: RejectReason::OrderNotFound,
        }
    );
}

// ============================================================================
// 7. 幽灵订单跳过 (Ghost Order Skip)
// ============================================================================

#[test]
fn test_ghost_order_skipped() {
    let mut book = OrderBook::new();

    // 挂 A(id=1) 和 B(id=2) 两个卖单在同一价格
    book.process_order(ask(1, 100_000_000, 50, 10));
    book.process_order(ask(2, 100_000_000, 50, 20));

    // 撤掉 A
    book.cancel_order(1);

    // 市价买入 30 → 应跳过 A(幽灵)，吃 B
    let events = book.process_order(market_bid(3, 30, 30));
    assert_eq!(events.len(), 1);
    match &events[0] {
        MatchEvent::Trade {
            maker_order_id,
            maker_agent_id,
            amount,
            ..
        } => {
            assert_eq!(*maker_order_id, 2); // B 被吃，不是 A
            assert_eq!(*maker_agent_id, 20);
            assert_eq!(*amount, Vol(30));
        }
        _ => panic!("Expected Trade with order B"),
    }
}

// ============================================================================
// 8. GC 回收
// ============================================================================

#[test]
fn test_gc_cleans_phantom_orders() {
    let mut book = OrderBook::new();

    book.process_order(bid(1, 100_000_000, 50, 1));
    book.cancel_order(1);

    // 撤单后 VecDeque 里还有实体 (幽灵)
    assert_eq!(book.phantom_count(), 1);

    // GC 清理
    let report = book.gc_phantom_orders();
    assert_eq!(report.cleaned_count, 1);
    assert_eq!(report.remaining_orders, 0);
    assert_eq!(report.removed_levels, 1); // 空档位被移除

    assert_eq!(book.phantom_count(), 0);

    // L2 完全清空
    let (bids, asks) = book.get_l2_snapshot(5);
    assert!(bids.is_empty());
    assert!(asks.is_empty());
}

#[test]
fn test_phantom_count() {
    let mut book = OrderBook::new();

    // 挂 5 个卖单
    for i in 0..5 {
        book.process_order(ask(i + 1, 100_000_000, 10, 1));
    }

    // 撤 3 个
    book.cancel_order(1);
    book.cancel_order(3);
    book.cancel_order(5);

    assert_eq!(book.phantom_count(), 3);
}

// ============================================================================
// 9. 不价格交叉不成交 (No Cross = No Trade)
// ============================================================================

#[test]
fn test_no_cross_no_trade() {
    let mut book = OrderBook::new();

    // 买单 99 元
    book.process_order(bid(1, 99_000_000, 50, 1));
    // 卖单 101 元 → 价格不交叉，两者都挂单
    let events = book.process_order(ask(2, 101_000_000, 50, 2));
    assert_eq!(
        events,
        vec![MatchEvent::Placed {
            order_id: 2,
            price: Price(101_000_000),
            amount: Vol(50),
            remaining: Vol(50),
            side: Side::Ask,
        }]
    );

    // L2 应有 1 档买 + 1 档卖
    let (bids, asks) = book.get_l2_snapshot(5);
    assert_eq!(bids.len(), 1);
    assert_eq!(asks.len(), 1);

    // Best Bid < Best Ask
    assert!(book.best_bid().unwrap() < book.best_ask().unwrap());
}

// ============================================================================
// 10. 综合场景
// ============================================================================

#[test]
fn test_mixed_scenario() {
    let mut book = OrderBook::new();

    // 挂三个卖单
    book.process_order(ask(1, 101_000_000, 100, 1));
    book.process_order(ask(2, 102_000_000, 100, 2));
    book.process_order(ask(3, 103_000_000, 100, 3));

    // 撤掉中间一个
    book.cancel_order(2);

    // 大额买单 250 股 at 103 → 应吃 #1(100) + 跳过#2(撤了) + 吃#3(100) + 挂单 50
    let events = book.process_order(bid(4, 103_000_000, 250, 4));

    let trades: Vec<_> = events
        .iter()
        .filter_map(|e| match e {
            MatchEvent::Trade {
                maker_order_id,
                amount,
                ..
            } => Some((*maker_order_id, *amount)),
            _ => None,
        })
        .collect();

    // 只挂了id=2在102，但已撤单，不应参与撮合
    assert_eq!(trades.len(), 2);
    assert_eq!(trades[0], (1, Vol(100))); // 吃 101 元的 100 股
    assert_eq!(trades[1], (3, Vol(100))); // 吃 103 元的 100 股

    // 剩余 50 股挂入买盘
    assert!(events.iter().any(|e| matches!(
        e,
        MatchEvent::Placed {
            order_id: 4,
            price,
            amount,
            remaining,
            side: Side::Bid,
        } if *price == Price(103_000_000) && *remaining == Vol(50) && *amount == Vol(250)
    )));

    // 验证买盘
    let (bids, asks) = book.get_l2_snapshot(5);
    assert_eq!(bids.len(), 1);
    assert_eq!(bids[0], (Price(103_000_000), Vol(50)));
    assert!(asks.is_empty());
}

// ============================================================================
// 11. 统计信息 (Engine Stats)
// ============================================================================

#[test]
fn test_engine_stats() {
    let mut book = OrderBook::new();

    // 4 个订单:挂单 3 个 (ask 1,2,3) + 1 个撮合订单 (bid 4)
    book.process_order(ask(1, 101_000_000, 100, 1));
    book.process_order(ask(2, 102_000_000, 100, 2));
    book.process_order(ask(3, 103_000_000, 100, 3));

    // 撤单 1 笔
    book.cancel_order(2);

    // 市价单吃 150 股 → 2 笔成交 (ask#1 100 + ask#3 50)
    book.process_order(market_bid(4, 150, 4));

    let stats = book.stats();
    assert_eq!(stats.total_orders, 4); // 4 次 process_order
    assert_eq!(stats.total_placed, 3); // ask 1,2,3 挂单
    assert_eq!(stats.total_cancels, 1); // 撤单 ask#2
    assert_eq!(stats.total_trades, 2); // 2 笔成交
    assert_eq!(stats.total_trade_volume, Vol(150)); // 100 + 50
    assert_eq!(stats.total_rejects, 0);
}

#[test]
fn test_stats_rejects() {
    let mut book = OrderBook::new();

    // 撤不存在的单
    book.cancel_order(999);
    // 市价单无流动性
    book.process_order(market_bid(1, 100, 1));

    let stats = book.stats();
    assert_eq!(stats.total_rejects, 2); // 1 OrderNotFound + 1 InsufficientLiquidity
    assert_eq!(stats.total_orders, 1); // 只有 1 次 process_order
    assert_eq!(stats.total_cancels, 0); // 撤单失败不算成功撤单
}
