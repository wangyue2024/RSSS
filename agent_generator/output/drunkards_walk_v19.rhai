let initialized = false;
let stop_loss_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(500_000, 2_000_000);
    }

    if !market.trading_enabled {
        return;
    }

    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    if market.tick >= market.total_ticks / 5 {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let r = rng.rand_int(0, 99);

    if r < 5 {
        let qty = rng.rand_int(1, 100);
        let offset = rng.rand_int(-20, 0) * 10_000;
        let price = market.price + offset;
        if price < 1 {
            price = 1;
        }
        orders.submit_limit_buy(price, qty);
    } else if r > 95 {
        let qty = rng.rand_int(1, 100);
        let offset = rng.rand_int(0, 20) * 10_000;
        let price = market.price + offset;
        orders.submit_limit_sell(price, qty);
    }
}