let initialized = false;
let fair_value = 0;
let lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let random_offset = rng.rand_int(-5_000_000, 5_000_000);
        fair_value = 100_000_000 + random_offset;
        lot_size = account.cash * 50 / 100;
    }

    if !market.trading_enabled { return; }
    if market.tick >= market.total_ticks / 5 { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.price > fair_value * 110 / 100 && account.stock > 0 {
        let aggressive_amount = lot_size / market.price;
        if aggressive_amount > 0 {
            orders.submit_limit_sell(market.price, aggressive_amount);
        }
    } else if market.price > fair_value * 105 / 100 && account.stock > 0 {
        let small_amount = (lot_size / market.price) * 10 / 100;
        if small_amount > 0 {
            orders.submit_limit_sell(market.price, small_amount);
        }
    }
}