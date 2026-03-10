let initialized = false;
let panic_threshold = 0;
let lookback_period = 20;
let prev_slope = 0;
let slope_window = 15;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(50_000, 200_000);
        lookback_period = 20;
        prev_slope = 0;
        slope_window = 15;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    if market.history_len() < slope_window {
        return;
    }

    let price_arr = [];
    let j = 0;
    while j < slope_window {
        price_arr.push(market.history_price(j));
        j += 1;
    }

    let current_slope = math.slope(price_arr);
    let slope_accel = current_slope - prev_slope;
    prev_slope = current_slope;

    let aggressive_buy = current_slope > 2000 && slope_accel > 500;
    let panic_sell = current_slope < -1000 && prev_slope > 0;

    if panic_sell && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    if aggressive_buy && account.cash > 2_000_000 {
        let raw_price = market.price + 10_000;
        let round_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
        let max_afford = account.cash / round_price;
        let buy_amount = max_afford * 30 / 100;
        if buy_amount > 0 {
            orders.submit_limit_buy(round_price, buy_amount);
        }
    } else if current_slope < -500 && account.stock > 0 {
        let raw_price = market.price - 10_000;
        let round_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
        if round_price > 0 {
            orders.submit_limit_sell(round_price, account.stock);
        }
    }
}