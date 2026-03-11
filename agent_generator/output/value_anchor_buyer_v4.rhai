let initialized = false;
let fair_value_micros = 0;
let aggressive_fraction = 0;
let small_fraction = 0;
let price_buffer = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value_micros = rng.rand_int(95_000_000, 105_000_000);
        aggressive_fraction = rng.rand_int(40, 60);
        small_fraction = rng.rand_int(5, 15);
    }

    if !market.trading_enabled { return; }

    price_buffer.push(market.price);
    if price_buffer.len() > 6 {
        price_buffer.remove(0);
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if price_buffer.len() < 6 { return; }
    let delayed_price = price_buffer[0];

    let aggressive_threshold = fair_value_micros * 90 / 100;
    let small_threshold = fair_value_micros * 95 / 100;

    if delayed_price < aggressive_threshold && account.cash > 0 {
        let buy_cash = account.cash * aggressive_fraction / 100;
        let buy_amount = buy_cash / delayed_price;
        if buy_amount == 0 { buy_amount = 1; }
        orders.submit_limit_buy(delayed_price, buy_amount);
    } else if delayed_price < small_threshold && account.cash > 0 {
        let buy_cash = account.cash * small_fraction / 100;
        let buy_amount = buy_cash / delayed_price;
        if buy_amount == 0 { buy_amount = 1; }
        orders.submit_limit_buy(delayed_price, buy_amount);
    } else if delayed_price > account.avg_cost && account.stock > 0 {
        orders.submit_limit_sell(delayed_price, account.stock);
    }
}