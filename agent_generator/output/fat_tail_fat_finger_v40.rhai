let base_order_amount = 1000;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 {
        return;
    }
    
    let fat_finger_chance = rng.rand_int(0, 9999);
    if fat_finger_chance != 0 {
        return;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let is_buy = rng.rand_bool(50);
    let fat_amount = base_order_amount * 100;
    
    if is_buy {
        orders.submit_market_buy(fat_amount);
    } else {
        orders.submit_market_sell(fat_amount);
    }
}