let initialized = false;
let lookback = 20;
let delay = 5;
let last_slope = 0;
let price_buffer = [];
let slope_buffer = [];
let buy_aggression = 0;
let sell_trigger = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        buy_aggression = rng.rand_int(500_000, 1_500_000);
        sell_trigger = rng.rand_int(100_000, 300_000);
        for i in 0..lookback {
            price_buffer.push(market.price);
        }
        for i in 0..3 {
            slope_buffer.push(0);
        }
        return;
    }
    
    price_buffer.push(market.price);
    if price_buffer.len() > lookback {
        price_buffer.remove(0);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_buffer.len() < lookback {
        return;
    }
    
    let delayed_prices = [];
    let start_idx = price_buffer.len() - lookback;
    let j = 0;
    while j < lookback {
        delayed_prices.push(price_buffer[start_idx + j]);
        j += 1;
    }
    
    let current_slope = arr_slope(delayed_prices);
    
    slope_buffer.push(current_slope);
    if slope_buffer.len() > 3 {
        slope_buffer.remove(0);
    }
    
    if slope_buffer.len() < 3 {
        last_slope = current_slope;
        return;
    }
    
    let slope_accel = current_slope - last_slope;
    let avg_slope = (slope_buffer[0] + slope_buffer[1] + slope_buffer[2]) / 3;
    
    let price_delayed = price_buffer[price_buffer.len() - delay - 1];
    
    if current_slope > buy_aggression && slope_accel > 0 && avg_slope > 0 {
        let rounded_price = ((price_delayed + 500_000) / 1_000_000) * 1_000_000;
        let cash_to_use = account.cash * 30 / 100;
        let buy_amount = cash_to_use / rounded_price;
        if buy_amount > 0 {
            orders.submit_limit_buy(rounded_price, buy_amount);
        }
    }
    
    if last_slope > sell_trigger && current_slope < -sell_trigger {
        if account.stock > 0 {
            let rounded_price = ((price_delayed + 500_000) / 1_000_000) * 1_000_000;
            let sell_amount = account.stock;
            orders.submit_limit_sell(rounded_price, sell_amount);
        }
    }
    
    last_slope = current_slope;
}