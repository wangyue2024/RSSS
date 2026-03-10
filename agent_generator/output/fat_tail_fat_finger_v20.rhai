let initialized = false;
let base_order_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_order_size = rng.rand_int(100, 500);
    }
    
    if !market.trading_enabled { return; }
    
    let lazy_tick = market.tick % 50 == 0;
    if !lazy_tick { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fat_finger_roll = rng.rand_int(0, 9999);
    if fat_finger_roll == 0 {
        let fat_finger_side = rng.rand_bool(50);
        let fat_finger_amount = base_order_size * 100;
        
        if fat_finger_side {
            orders.submit_market_buy(fat_finger_amount);
        } else {
            orders.submit_market_sell(fat_finger_amount);
        }
    }
}