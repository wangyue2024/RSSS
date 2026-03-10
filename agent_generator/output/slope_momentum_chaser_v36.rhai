let initialized = false;
let slope_window = 10;
let reaction_delay = 5;
let momentum_threshold = 20000;
let panic_threshold = -10000;
let prev_price_buffer = [];
let slope_buffer = [];

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if market.history_len() < reaction_delay + slope_window {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let delayed_price = market.history_price(reaction_delay);
    prev_price_buffer.push(delayed_price);
    if prev_price_buffer.len() > slope_window {
        prev_price_buffer.remove(0);
    }
    
    if prev_price_buffer.len() == slope_window {
        let current_slope = arr_slope(prev_price_buffer);
        slope_buffer.push(current_slope);
        if slope_buffer.len() > 2 {
            slope_buffer.remove(0);
        }
        
        let accelerating = false;
        if slope_buffer.len() == 2 {
            if slope_buffer[1] > slope_buffer[0] && slope_buffer[1] > momentum_threshold {
                accelerating = true;
            }
        }
        
        if current_slope < panic_threshold {
            if account.stock > 0 {
                orders.submit_market_sell(account.stock);
            }
        } else if accelerating {
            let rounded_price = ((market.price + 500000) / 1000000) * 1000000;
            let cash_to_use = account.cash * 8 / 10;
            let amount = cash_to_use / rounded_price;
            if amount > 0 && rounded_price > 0 {
                orders.submit_limit_buy(rounded_price, amount);
            }
        }
    }
}