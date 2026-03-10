// Global state
let price_history = [];
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled {
        return;
    }

    // Update price history for FOMO calculation
    price_history.push(market.price);
    if price_history.len() > 11 {
        price_history.remove(0);
    }

    // Check for FOMO condition (every tick)
    if price_history.len() == 11 {
        let old_price = price_history[0];
        let new_price = price_history[10];
        let change_bps = (new_price - old_price) * 10000 / old_price;
        
        if change_bps > 200 {
            // FOMO market buy with normal size
            orders.submit_market_buy(100);
            return;  // Skip other actions this tick
        }
    }

    // Check for fat finger condition (every tick)
    let fat_finger_roll = rng.rand_int(0, 9999);
    if fat_finger_roll == 0 {
        let is_buy = rng.rand_bool(50);
        let normal_size = 100;
        let fat_finger_size = normal_size * 100;
        
        if is_buy {
            orders.submit_market_buy(fat_finger_size);
        } else {
            orders.submit_market_sell(fat_finger_size);
        }
        return;
    }

    // Lazy trader: only evaluate market every 50 ticks
    if market.tick % 50 == 0 {
        // Main strategy does nothing on evaluation
        // This space intentionally left blank
    }
}