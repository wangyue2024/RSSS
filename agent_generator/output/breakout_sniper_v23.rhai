let initialized = false;
let lot_fraction = 0;
let stop_offset = 50000;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        lot_fraction = rng.rand_int(25, 50);
        stop_offset = rng.rand_int(3, 7) * 10000;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.stock > 0 {
        let stop_price = account.avg_cost - stop_offset;
        if stop_price > 0 {
            orders.submit_limit_sell(stop_price, account.stock);
        }
    } else {
        if market.price > market.high_20 {
            let max_cash_use = account.cash * lot_fraction / 100;
            let amount = max_cash_use / market.price;
            if amount > 0 {
                orders.submit_market_buy(amount);
            }
        }
    }
}