let initialized = false;
let lot_size = 0;
let active = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        let risk_frac = rng.rand_int(30, 50);
        lot_size = account.cash * risk_frac / 100;
        if lot_size < 1 {
            lot_size = 1;
        }
    }

    if !market.trading_enabled { return; }

    active = market.tick < market.total_ticks / 5;

    if !active {
        let pcount = my_orders.pending_count();
        let i = 0;
        while i < pcount {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }

    let pcount = my_orders.pending_count();
    let i = 0;
    while i < pcount {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    let dice = rng.rand_int(0, 99);

    if dice < 5 {
        let qty = rng.rand_int(1, lot_size);
        if qty < 1 { qty = 1; }
        let offset = rng.rand_int(-10000, 10000);
        let price = market.price + offset;
        if price < 1 { price = 1; }
        orders.submit_limit_buy(price, qty);
    } else if dice > 95 {
        let max_sell = account.stock;
        if max_sell > 0 {
            let qty = rng.rand_int(1, max_sell);
            if qty < 1 { qty = 1; }
            let offset = rng.rand_int(-10000, 10000);
            let price = market.price + offset;
            if price < 1 { price = 1; }
            orders.submit_limit_sell(price, qty);
        }
    }
}