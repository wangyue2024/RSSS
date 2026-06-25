let initialized = false;
let normal_size = 0;
let check_interval = 50;

fn on_tick() {
    if !initialized {
        initialized = true;
        normal_size = rng.rand_int(50, 200);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if market.history_len() > 5 {
        let current_price = market.price;
        let price_5_ago = market.history_price(5);
        if price_5_ago > 0 {
            let price_change_pct = (current_price - price_5_ago) * 10000 / price_5_ago;
            if price_change_pct > 200 {
                orders.submit_market_buy(normal_size);
                return;
            }
        }
    }
    
    if market.tick % check_interval == 0 {
        let fat_finger_chance = rng.rand_int(0, 9999);
        if fat_finger_chance == 0 {
            if rng.rand_bool(50) {
                orders.submit_market_buy(normal_size * 100);
            } else {
                orders.submit_market_sell(normal_size * 100);
            }
        }
    }
}