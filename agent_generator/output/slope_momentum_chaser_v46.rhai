let initialized = false;
let short_lookback = 5;
let long_lookback = 20;
let max_position_percent = 0;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        max_position_percent = rng.rand_int(30, 50);
        panic_threshold = rng.rand_int(-100, -50);
    }

    if !market.trading_enabled { return; }
    if market.tick >= market.total_ticks * 2 / 10 { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let short_prices = [];
    let i = 0;
    while i < short_lookback && i < market.history_len() {
        short_prices.push(market.history_price(i));
        i += 1;
    }
    let short_slope = arr_slope(short_prices);

    let long_prices = [];
    let i = 0;
    while i < long_lookback && i < market.history_len() {
        long_prices.push(market.history_price(i));
        i += 1;
    }
    let long_slope = arr_slope(long_prices);

    let cash_to_use = account.cash * max_position_percent / 100;
    let buy_amount = cash_to_use / market.price;
    let sell_amount = account.stock;

    if short_slope > 0 && short_slope > long_slope && buy_amount > 0 {
        let price = market.ask_price_0;
        if price == 0 { price = market.price; }
        orders.submit_limit_buy(price, buy_amount);
    } else if short_slope < panic_threshold && sell_amount > 0 {
        let price = market.bid_price_0;
        if price == 0 { price = market.price; }
        orders.submit_limit_sell(price, sell_amount);
    }
}