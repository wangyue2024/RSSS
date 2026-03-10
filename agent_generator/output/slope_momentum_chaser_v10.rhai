let initialized = false;
let decision_tick = 0;
let buy_threshold = 0;
let panic_slope_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        decision_tick = rng.rand_int(0, 49);
        buy_threshold = rng.rand_int(1000, 3000);
        panic_slope_threshold = rng.rand_int(-2000, -500);
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;
    if current_tick % 50 != decision_tick { return; }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let history_len = market.history_len();
    if history_len < 5 { return; }

    let recent_prices = [];
    let j = 0;
    while j < 5 && j < history_len {
        recent_prices.push(market.history_price(j));
        j += 1;
    }

    let slope = arr_slope(recent_prices);
    let slope_prev = 0;

    if history_len >= 10 {
        let prev_prices = [];
        let k = 5;
        while k < 10 && k < history_len {
            prev_prices.push(market.history_price(k));
            k += 1;
        }
        slope_prev = arr_slope(prev_prices);
    }

    let aggressive_buy = slope > buy_threshold && (slope_prev == 0 || slope > slope_prev);
    let panic_sell = slope < panic_slope_threshold && market.price > account.avg_cost;

    if aggressive_buy && account.cash > 1_000_000 {
        let target_price = market.price + 500_000;
        let rounded_price = (target_price / 1_000_000) * 1_000_000;
        let max_buy_amount = account.cash / rounded_price;
        if max_buy_amount > 0 {
            let buy_amount = clamp_val(max_buy_amount, 1, 100);
            orders.submit_limit_buy(rounded_price, buy_amount);
        }
    }

    if panic_sell && account.stock > 0 {
        let target_price = market.price - 500_000;
        let rounded_price = (target_price / 1_000_000) * 1_000_000;
        if rounded_price > account.avg_cost {
            let sell_amount = clamp_val(account.stock, 1, 100);
            orders.submit_limit_sell(rounded_price, sell_amount);
        }
    }
}