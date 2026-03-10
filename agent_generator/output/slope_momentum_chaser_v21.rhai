let initialized = false;
let lot_size = 0;
let price_history = [];
let price_buffer = [];

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        let five_percent_cap = account.total_equity * 50000 / 1000000;
        let max_shares = five_percent_cap / market.price;
        if max_shares < 1 {
            max_shares = 1;
        }
        lot_size = rng.rand_int(1, max_shares);
    }
    
    let vol_threshold = market.price * 500 / 10000;
    if market.std_dev > vol_threshold {
        return;
    }
    
    price_buffer.push(market.price);
    if price_buffer.len() > 5 {
        let delayed_price = price_buffer.remove(0);
        price_history.push(delayed_price);
        if price_history.len() > 20 {
            price_history.remove(0);
        }
    }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_history.len() < 10 {
        return;
    }
    
    let slope_arr = [];
    let start = price_history.len() - 10;
    let j = start;
    while j < price_history.len() {
        slope_arr.push(price_history[j]);
        j += 1;
    }
    
    let current_slope = arr_slope(slope_arr);
    
    let prev_slope_arr = [];
    if price_history.len() >= 20 {
        let prev_start = price_history.len() - 20;
        let k = prev_start;
        while k < prev_start + 10 {
            prev_slope_arr.push(price_history[k]);
            k += 1;
        }
    }
    
    let prev_slope = 0;
    if prev_slope_arr.len() == 10 {
        prev_slope = arr_slope(prev_slope_arr);
    }
    
    if current_slope > 5000 && current_slope > prev_slope * 150 / 100 {
        let buy_price = market.bid_price_0;
        if buy_price > 0 {
            orders.submit_limit_buy(buy_price, lot_size);
        }
    }
    
    if current_slope < -3000 && prev_slope > 1000 {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
    }
}