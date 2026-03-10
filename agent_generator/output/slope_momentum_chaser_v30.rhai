let price_history = [];
let initialized = false;
let LONG_WINDOW = 20;
let SHORT_WINDOW = 10;
let DELAY_TICKS = 5;

fn round_to_dollar(price) {
    ((price + 500_000) / 1_000_000) * 1_000_000
}

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > LONG_WINDOW + DELAY_TICKS {
        price_history.remove(0);
    }
    
    if price_history.len() < LONG_WINDOW + DELAY_TICKS { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let delayed_prices = [];
    let start_idx = price_history.len() - DELAY_TICKS - LONG_WINDOW;
    let end_idx = price_history.len() - DELAY_TICKS;
    
    let j = start_idx;
    while j < end_idx {
        delayed_prices.push(price_history[j]);
        j += 1;
    }
    
    if delayed_prices.len() < LONG_WINDOW { return; }
    
    let long_slope_arr = [];
    let short_slope_arr = [];
    
    let k = 0;
    while k < LONG_WINDOW - 1 {
        long_slope_arr.push(delayed_prices[k + 1] - delayed_prices[k]);
        k += 1;
    }
    
    let m = LONG_WINDOW - SHORT_WINDOW;
    while m < LONG_WINDOW - 1 {
        short_slope_arr.push(delayed_prices[m + 1] - delayed_prices[m]);
        m += 1;
    }
    
    let long_slope = arr_mean(long_slope_arr);
    let short_slope = arr_mean(short_slope_arr);
    let long_accel = arr_slope(long_slope_arr);
    
    let current_delayed_price = delayed_prices[delayed_prices.len() - 1];
    
    if account.stock == 0 {
        if short_slope > 50_000 && long_slope > 20_000 && long_accel > 5_000 {
            let buy_price = round_to_dollar(current_delayed_price);
            let amount = (account.cash * 80) / 100 / buy_price;
            if amount > 0 {
                orders.submit_limit_buy(buy_price, amount);
            }
        }
    } else {
        if short_slope < -30_000 {
            orders.submit_market_sell(account.stock);
        } else if short_slope > 100_000 && long_accel > 10_000 {
            let sell_price = round_to_dollar(current_delayed_price + 500_000);
            orders.submit_limit_sell(sell_price, account.stock / 2);
        }
    }
}