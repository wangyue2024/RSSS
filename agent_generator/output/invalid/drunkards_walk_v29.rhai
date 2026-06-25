let initialized = false;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(1_000_000, 10_000_000);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let r = rng.rand_int(0, 99);
    if r < 5 {
        let qty = rng.rand_int(1, 100);
        let offset = rng.rand_int(-100_000, 100_000);
        let price = market.price + offset;
        if price > 0 {
            orders.submit_limit_buy(price, qty);
        }
    } else if r > 95 {
        let qty = rng.rand_int(1, 100);
        if qty > account.stock {
            qty = account.stock;
        }
        if qty > 0 {
            let offset = rng.rand_int(-100_000, 100_000);
            let price = market.price + offset;
            if price > 0 {
                orders.submit_limit_sell(price, qty);
            }
        }
    }
}