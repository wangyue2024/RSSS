let last_eval_tick = -1;
let normal_size = 10000;
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        normal_size = rng.rand_int(5000, 15000);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    if rng.rand_int(0, 9999) == 0 {
        let fat_finger_size = normal_size * 100;
        if rng.rand_bool(50) {
            orders.submit_market_buy(fat_finger_size);
        } else {
            orders.submit_market_sell(fat_finger_size);
        }
        return;
    }
    
    if market.history_len() >= 5 {
        let price_now = market.price;
        let price_5_ago = market.history_price(5);
        if price_5_ago != 0 {
            let change_threshold = price_5_ago * 200 / 10000;
            if (price_now - price_5_ago) > change_threshold {
                orders.submit_market_buy(normal_size);
                return;
            }
        }
    }
    
    if current_tick % 50 == 0 && current_tick != last_eval_tick {
        last_eval_tick = current_tick;
        
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        if rng.rand_bool(50) {
            orders.submit_market_buy(normal_size);
        } else {
            orders.submit_market_sell(normal_size);
        }
    }
}