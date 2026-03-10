let initialized = false;
let normal_lot_size = 0;
let fat_finger_lot_size = 0;

fn on_tick() {
    if !initialized {
        let risk_level = rng.rand_int(0, 100);
        if risk_level < 50 {
            normal_lot_size = account.total_equity * rng.rand_int(250, 500) / 10000;
        } else {
            normal_lot_size = account.total_equity * rng.rand_int(10, 50) / 10000;
        }
        if normal_lot_size < 1_000_000 {
            normal_lot_size = 1_000_000;
        }
        fat_finger_lot_size = normal_lot_size * 100;
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
    
    let fat_finger_chance = rng.rand_int(0, 9999);
    
    if fat_finger_chance == 0 {
        let direction = rng.rand_bool(50);
        
        if direction {
            let amount = fat_finger_lot_size;
            if amount > 0 {
                orders.submit_market_buy(amount);
            }
        } else {
            let amount = fat_finger_lot_size;
            if amount > 0 && account.stock > 0 {
                orders.submit_market_sell(amount);
            }
        }
    }
}