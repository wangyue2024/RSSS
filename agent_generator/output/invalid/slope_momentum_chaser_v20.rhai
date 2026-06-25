let initialized = false;
let prev_short_slope = 0;
let prev_long_slope = 0;
let base_shares = 0;
let panic_mode = false;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_shares = rng.rand_int(8000, 12000);
        panic_threshold = rng.rand_int(-15000, -5000);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks * 2 / 10 {
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    let hist_len = market.history_len();
    if hist_len < 20 { return; }
    
    let price_arr_short = [];
    let price_arr_long = [];
    let j = 0;
    while j < 10 {
        price_arr_short.push(market.history_price(j));
        j += 1;
    }
    let k = 0;
    while k < 20 {
        price_arr_long.push(market.history_price(k));
        k += 1;
    }
    
    let short_slope = arr_slope(price_arr_short);
    let long_slope = arr_slope(price_arr_long);
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if panic_mode {
        if short_slope > 0 && long_slope > 0 {
            panic_mode = false;
        } else if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
    } else {
        if short_slope < panic_threshold && prev_short_slope >= 0 {
            panic_mode = true;
            if account.stock > 0 {
                orders.submit_market_sell(account.stock);
            }
        } else if short_slope > 5000 && short_slope > long_slope * 2 && long_slope > 0 {
            let buy_power = account.cash / market.price;
            let shares_to_buy = clamp_val(base_shares, 1000, buy_power);
            if shares_to_buy > 0 {
                let aggro = clamp_val(short_slope / 1000, 1, 5);
                let target_price = market.price + (market.ask_price_0 - market.bid_price_0) * aggro / 2;
                orders.submit_limit_buy(target_price, shares_to_buy);
            }
        }
    }
    
    prev_short_slope = short_slope;
    prev_long_slope = long_slope;
}