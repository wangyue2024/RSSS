let initialized = false;
let fair_value_micros = 0;

fn on_tick() {
    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if !initialized {
        initialized = true;
        let base_fair = 100_000_000;
        let random_offset = rng.rand_int(-2_000_000, 2_000_000);
        fair_value_micros = base_fair + random_offset;
    }

    if market.tick >= market.total_ticks / 5 {
        return;
    }

    let current_price = market.price;
    let stock_to_sell = 0;

    if current_price > fair_value_micros * 110 / 100 && account.stock > 0 {
        stock_to_sell = account.stock * 15 / 100;
        if stock_to_sell == 0 { stock_to_sell = 1; }
        orders.submit_limit_sell(current_price, stock_to_sell);
    } else if current_price > fair_value_micros * 105 / 100 && account.stock > 0 {
        stock_to_sell = account.stock * 5 / 100;
        if stock_to_sell == 0 { stock_to_sell = 1; }
        orders.submit_limit_sell(current_price, stock_to_sell);
    }
}