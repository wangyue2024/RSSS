let initialized = false;
let short_window = 5;
let long_window = 20;
let slope_threshold_high = 50000;
let slope_threshold_low = -30000;
let last_slope_short = 0;
let last_slope_long = 0;
let panic_mode = false;
let panic_cooldown = 0;

fn round_to_dollar(price) {
    let remainder = price % 1_000_000;
    if remainder >= 500_000 {
        price - remainder + 1_000_000
    } else {
        price - remainder
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        slope_threshold_high = rng.rand_int(30000, 70000);
        slope_threshold_low = rng.rand_int(-50000, -10000);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if panic_mode {
        panic_cooldown -= 1;
        if panic_cooldown <= 0 {
            panic_mode = false;
        } else {
            if account.stock > 0 {
                orders.submit_market_sell(account.stock);
            }
            return;
        }
    }

    let history_len = market.history_len();
    if history_len < long_window + 1 { return; }

    let short_prices = [];
    let long_prices = [];
    let idx = 0;
    while idx <= short_window {
        short_prices.push(market.history_price(history_len - 1 - idx));
        idx += 1;
    }
    idx = 0;
    while idx <= long_window {
        long_prices.push(market.history_price(history_len - 1 - idx));
        idx += 1;
    }

    let slope_short = arr_slope(short_prices);
    let slope_long = arr_slope(long_prices);

    let accel_short = slope_short - last_slope_short;
    let accel_long = slope_long - last_slope_long;

    last_slope_short = slope_short;
    last_slope_long = slope_long;

    if slope_short < slope_threshold_low && slope_short < 0 && accel_short < -20000 {
        panic_mode = true;
        panic_cooldown = rng.rand_int(5, 15);
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    if slope_short > slope_threshold_high && accel_short > 0 && slope_short > slope_long {
        let buy_price = round_to_dollar(market.price);
        if buy_price > market.ask_price_0 {
            buy_price = buy_price - 1_000_000;
        }
        if buy_price <= 0 { return; }

        let max_shares = account.cash / buy_price;
        if max_shares <= 0 { return; }

        let aggression = clamp_val(accel_short / 1000, 1, 10);
        let shares_to_buy = max_shares * aggression / 10;
        if shares_to_buy > 0 {
            orders.submit_limit_buy(buy_price, shares_to_buy);
        }

        let cash_remaining = account.cash - (shares_to_buy * buy_price);
        if cash_remaining > 10_000_000 && rng.rand_bool(30) {
            let second_price = buy_price - 1_000_000;
            if second_price > 0 {
                let second_shares = cash_remaining / second_price / 2;
                if second_shares > 0 {
                    orders.submit_limit_buy(second_price, second_shares);
                }
            }
        }
    } else if slope_short < 0 && account.stock > 0 {
        let sell_price = round_to_dollar(market.price);
        if sell_price < market.bid_price_0 {
            sell_price = sell_price + 1_000_000;
        }
        let shares_to_sell = account.stock * 3 / 10;
        if shares_to_sell > 0 {
            orders.submit_limit_sell(sell_price, shares_to_sell);
        }
    }
}