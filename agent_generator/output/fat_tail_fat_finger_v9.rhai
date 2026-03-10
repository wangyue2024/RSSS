let initialized = false;
let base_order_amount = 100;
let fat_finger_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fat_finger_chance = rng.rand_int(0, 9999) == 0;
    
    if fat_finger_chance {
        fat_finger_triggered = true;
        let buy_not_sell = rng.rand_bool(50);
        let fat_amount = base_order_amount * 100;
        
        if buy_not_sell {
            orders.submit_market_buy(fat_amount);
        } else {
            orders.submit_market_sell(fat_amount);
        }
        return;
    }
    
    fat_finger_triggered = false;
}