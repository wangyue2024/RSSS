let initialized = false;
let decision_counter = 0;
let panic_threshold_micros = 0;
let last_slope = 0;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        panic_threshold_micros = -rng.rand_int(50_000, 200_000);
        initialized = true;
    }

    if account.unrealized_pnl < panic_threshold_micros && account.stock > 0 {
        let pending_cnt = my_orders.pending_count();
        let j = 0;
        while j < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(j));
            j += 1;
        }
        orders.submit_market_sell(account.stock);
        return;
    }

    decision_counter += 1;
    if decision_counter % 50 != 0 {
        return;
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let lookback = 20;
    let history_len = market.history_len();
    let available = if lookback < history_len { lookback } else { history_len };
    if available < 5 {
        return;
    }
    let price_array = [];
    let idx = 0;
    while idx < available {
        price_array.push(market.history_price(idx));
        idx += 1;
    }
    let slope = arr_slope(price_array);

    if slope > 3000 && slope > last_slope {
        let buy_amount = account.cash / (market.price * 2);
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    }

    if slope < -1000 && last_slope > 0 && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }

    last_slope = slope;
}