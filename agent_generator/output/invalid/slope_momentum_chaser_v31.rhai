let initialized = false;
let price_window = [];
let delayed_prices = [];
let prev_slope = 0;
let window_size = 20;
let lookback = 5;
let buy_threshold = 15000;
let panic_threshold = -5000;
let position_size = 0;
let max_position = 1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        position_size = rng.rand_int(50, 200);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_window.push(market.price);
    if price_window.len() > window_size + lookback {
        price_window.remove(0);
    }
    
    if price_window.len() >= window_size + lookback {
        let delayed_arr = [];
        let start_idx = price_window.len() - window_size - lookback;
        let j = 0;
        while j < window_size {
            delayed_arr.push(price_window[start_idx + j]);
            j += 1;
        }
        
        let current_slope = arr_slope(delayed_arr);
        
        if current_slope > buy_threshold && current_slope > prev_slope {
            let available_cash = account.cash;
            let buy_amount = position_size;
            if buy_amount > 0 && available_cash > market.price * buy_amount {
                let limit_price = market.price * 1001 / 1000;
                orders.submit_limit_buy(limit_price, buy_amount);
            }
        } else if current_slope < panic_threshold && prev_slope > 0 {
            let stock_held = account.stock;
            if stock_held > 0 {
                orders.submit_market_sell(stock_held);
            }
        }
        
        prev_slope = current_slope;
    }
}