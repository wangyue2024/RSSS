let initialized = false;
let lot_size = 0;
let std_dev_threshold = 0;
let last_slope = 0;
let panic_mode = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        let equity_percent = rng.rand_int(1, 5);
        std_dev_threshold = rng.rand_int(25_000, 75_000);
        lot_size = (account.total_equity * equity_percent) / (100 * market.price);
        if lot_size < 1 { lot_size = 1; }
        last_slope = 0;
        panic_mode = false;
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.std_dev > std_dev_threshold {
        return;
    }

    let hist_len = market.history_len();
    if hist_len < 20 {
        return;
    }

    let price_history = [];
    let j = 0;
    while j < 20 {
        price_history.push(market.history_price(hist_len - 20 + j));
        j += 1;
    }

    let current_slope = arr_slope(price_history);

    if panic_mode {
        if current_slope >= 0 {
            panic_mode = false;
        } else {
            if account.stock > 0 {
                orders.submit_market_sell(account.stock);
            }
            return;
        }
    }

    let slope_accel = current_slope - last_slope;
    last_slope = current_slope;

    if current_slope > 1000 && slope_accel > 0 && account.cash > 1000000 {
        let raw_price = market.price - 5000;
        let round_price = (raw_price / 1_000_000) * 1_000_000;
        if round_price < market.bid_price_0 && round_price > 0 {
            let max_shares = account.cash / round_price;
            let shares = lot_size;
            if shares > max_shares { shares = max_shares; }
            if shares > 0 {
                orders.submit_limit_buy(round_price, shares);
            }
        }
    }

    if current_slope < -2000 {
        panic_mode = true;
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
    }
}