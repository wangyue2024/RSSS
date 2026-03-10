let initialized = false;
let base_order_amount = 0;
let my_last_action = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_order_amount = rng.rand_int(10, 100);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fat_finger_chance = rng.rand_int(0, 9999);
    if fat_finger_chance == 0 {
        let fat_amount = base_order_amount * 100;
        let side_roll = rng.rand_int(0, 1);
        if side_roll == 0 {
            orders.submit_market_buy(fat_amount);
        } else {
            orders.submit_market_sell(fat_amount);
        }
        my_last_action = market.tick;
        return;
    }
    
    let normal_chance = rng.rand_int(0, 99);
    if normal_chance == 0 && (market.tick - my_last_action) > 10 {
        let raw_price = market.price;
        let round_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
        
        let side_roll = rng.rand_int(0, 1);
        if side_roll == 0 {
            orders.submit_limit_buy(round_price, base_order_amount);
        } else {
            orders.submit_limit_sell(round_price, base_order_amount);
        }
        my_last_action = market.tick;
    }
}