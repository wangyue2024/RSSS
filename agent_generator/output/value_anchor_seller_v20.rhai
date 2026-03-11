let initialized = false;
let fair_value_micros = 0;
let price_history = [];

fn on_tick() {
    if !initialized {
        let base_fair_value = 100_000_000;
        let random_factor = rng.rand_int(98, 102);
        fair_value_micros = base_fair_value * random_factor / 100;
        initialized = true;
    }

    if !market.trading_enabled { return; }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if price_history.len() < 5 { return; }
    let delayed_price = price_history[0];

    if delayed_price > fair_value_micros * 105 / 100 {
        let sell_amount;
        if delayed_price > fair_value_micros * 110 / 100 {
            sell_amount = account.stock * 25 / 100;
        } else {
            sell_amount = account.stock * 10 / 100;
        }
        if sell_amount > 0 {
            orders.submit_limit_sell(delayed_price, sell_amount);
        }
    }
}