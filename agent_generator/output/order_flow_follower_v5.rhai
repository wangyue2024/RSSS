let initialized = false;
let stop_loss_threshold = 0;
let last_decision_tick = -50;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        stop_loss_threshold = -rng.rand_int(50_000, 500_000);
        initialized = true;
    }

    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    if market.tick - last_decision_tick < 50 { return; }
    last_decision_tick = market.tick;

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.buy_volume > 3 * market.sell_volume {
        if account.cash > 100_000 {
            let buy_amount = account.cash / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
    } else {
        if market.price > account.avg_cost && account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
    }
}