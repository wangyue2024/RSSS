let initialized = false;
let base_order_size = 0;
let morning_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_order_size = rng.rand_int(5, 20);
        morning_ticks = market.total_ticks * 200 / 1000;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.tick > morning_ticks { return; }
    
    let fat_finger_roll = rng.rand_int(0, 9999);
    
    if fat_finger_roll == 0 {
        let direction = rng.rand_bool(50);
        let fat_amount = base_order_size * 100;
        
        if direction && fat_amount > 0 {
            orders.submit_market_buy(fat_amount);
        } else if fat_amount > 0 {
            orders.submit_market_sell(fat_amount);
        }
    } else {
        let normal_roll = rng.rand_int(0, 99);
        if normal_roll < 1 && base_order_size > 0 {
            let bid_price = market.bid_price_0 + 1;
            orders.submit_limit_buy(bid_price, base_order_size);
        }
    }
}