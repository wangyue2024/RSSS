let initialized = false;
let lot_size = 0;
let prev_slope = 0;
let prev_prev_slope = 0;
let panic_mode = false;
let panic_counter = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_lot_value = account.total_equity * 5 / 100;
        let max_shares = max_lot_value / market.price;
        if max_shares < 1 {
            max_shares = 1;
        }
        lot_size = rng.rand_int(1, max_shares);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let risk_threshold = market.price * 2 / 100;
    if market.std_dev > risk_threshold {
        return;
    }
    
    let hist_len = market.history_len();
    if hist_len < 5 {
        return;
    }
    
    let recent_prices = [];
    let num_points = 10;
    let start_idx = hist_len - num_points;
    if start_idx < 0 { start_idx = 0; }
    for idx in range(start_idx, hist_len) {
        recent_prices.push(market.history_price(idx));
    }
    
    let current_slope = arr_slope(recent_prices);
    
    if panic_mode {
        panic_counter -= 1;
        if panic_counter <= 0 {
            panic_mode = false;
        } else {
            if account.stock > 0 {
                let sell_price = market.bid_price_0 - 50;
                if sell_price > 0 {
                    orders.submit_limit_sell(sell_price, account.stock);
                }
            }
            return;
        }
    }
    
    if current_slope < -1000 {
        panic_mode = true;
        panic_counter = 10;
    }
    
    let slope_accel = current_slope - prev_slope;
    
    if current_slope > 500 && slope_accel > 0 && !panic_mode {
        if account.cash > market.price * lot_size {
            let buy_price = market.ask_price_0 + 50;
            if buy_price > 0 {
                orders.submit_limit_buy(buy_price, lot_size);
            }
        }
    }
    
    prev_prev_slope = prev_slope;
    prev_slope = current_slope;
}