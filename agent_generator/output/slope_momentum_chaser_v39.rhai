let initialized = false;
let lookback = 20;
let slope_threshold = 5000;
let panic_threshold = -3000;
let prev_slope = 0;
let momentum_state = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lookback = rng.rand_int(15, 30);
        slope_threshold = rng.rand_int(3000, 8000);
        panic_threshold = rng.rand_int(-6000, -1000);
    }
    
    if !market.trading_enabled { return; }
    
    let active_ticks = market.total_ticks * 20 / 100;
    if market.tick >= active_ticks {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let hist_len = market.history_len();
    if hist_len < lookback {
        return;
    }
    
    let prices = [];
    let j = 0;
    while j < lookback {
        prices.push(market.history_price(hist_len - lookback + j));
        j += 1;
    }
    
    let current_slope = arr_slope(prices);
    
    if current_slope < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        momentum_state = 0;
    } else if current_slope > slope_threshold && prev_slope > slope_threshold / 2 {
        if current_slope > prev_slope && momentum_state < 3 {
            momentum_state += 1;
        }
        let cash_to_use = account.cash * (20 + momentum_state * 20) / 100;
        if cash_to_use > 100000 && market.ask_price_0 > 0 {
            let buy_amount = cash_to_use / market.ask_price_0;
            if buy_amount > 0 {
                let price = market.ask_price_0 + 100;
                orders.submit_limit_buy(price, buy_amount);
            }
        }
    } else {
        momentum_state = 0;
    }
    
    prev_slope = current_slope;
}