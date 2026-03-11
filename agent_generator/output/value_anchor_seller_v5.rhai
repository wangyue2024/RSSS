let initialized = false;
let fair_value = 0;
let price_history = [];
let last_decision_tick = -100;

fn on_tick() {
    if !initialized {
        let random_offset = rng.rand_int(-5, 5);
        fair_value = 100_000_000 * (100 + random_offset) / 100;
        initialized = true;
    }

    if !market.trading_enabled { return; }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    if market.tick >= market.total_ticks / 5 {
        return;
    }

    if market.tick % 50 != 0 {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if price_history.len() < 5 {
        return;
    }
    let delayed_price = price_history[0];

    if delayed_price <= fair_value {
        return;
    }

    let threshold_5 = fair_value * 105 / 100;
    let threshold_10 = fair_value * 110 / 100;
    let stock_to_sell = 0;

    if delayed_price > threshold_10 {
        stock_to_sell = account.stock * 60 / 100;
    } else if delayed_price > threshold_5 {
        stock_to_sell = account.stock * 25 / 100;
    }

    if stock_to_sell > 0 {
        orders.submit_limit_sell(delayed_price, stock_to_sell);
    }
}