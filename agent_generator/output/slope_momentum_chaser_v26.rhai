let initialized = false;
let window_size = 0;
let jump_window = 0;
let lot_size_pct = 0;
let prev_slope = 0;
let last_price = 0;
let panic_mode = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        window_size = rng.rand_int(15, 30);
        jump_window = rng.rand_int(3, 8);
        lot_size_pct = rng.rand_int(30, 50);
        last_price = market.price;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    
    if market.history_len() >= jump_window {
        let past_price = market.history_price(jump_window - 1);
        let change = current_price - past_price;
        let change_pct = change * 10000 / past_price;
        
        if change_pct > 200 && !panic_mode {
            let buy_amount = account.cash * lot_size_pct / 100;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
                panic_mode = true;
                return;
            }
        }
    }
    
    if market.history_len() >= window_size {
        let prices = [];
        let idx = 0;
        while idx < window_size {
            prices.push(market.history_price(idx));
            idx += 1;
        }
        
        let slope = arr_slope(prices);
        
        if panic_mode {
            if slope < 0 {
                if account.stock > 0 {
                    orders.submit_market_sell(account.stock);
                }
                panic_mode = false;
            }
        } else {
            if slope > 0 && slope > prev_slope * 3 / 2 {
                let buy_amount = account.cash * lot_size_pct / 100;
                if buy_amount > 0 {
                    let target_price = current_price * 102 / 100;
                    orders.submit_limit_buy(target_price, buy_amount);
                }
            }
            
            if slope < 0 && prev_slope > 0 {
                panic_mode = true;
                if account.stock > 0 {
                    orders.submit_market_sell(account.stock);
                }
            }
        }
        
        prev_slope = slope;
    }
    
    last_price = current_price;
}