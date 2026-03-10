let initialized = false;
let lot_size = 0;
let avg_cost_threshold = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        
        let capital_percent = rng.rand_int(1, 5);
        let target_capital = account.total_equity * capital_percent / 100;
        let price = market.price;
        if price > 0 {
            lot_size = target_capital / price;
        }
        if lot_size < 1 {
            lot_size = 1;
        }
        
        avg_cost_threshold = account.avg_cost;
    }
    
    if market.std_dev > 2_000_000 {
        return;
    }
    
    let fat_finger_triggered = rng.rand_int(0, 9999) == 0;
    
    if !fat_finger_triggered {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fat_amount = lot_size * 100;
    
    if account.stock > 0 && market.price > avg_cost_threshold {
        if rng.rand_bool(50) {
            orders.submit_market_sell(fat_amount);
        } else {
            orders.submit_market_buy(fat_amount);
        }
    } else {
        orders.submit_market_buy(fat_amount);
    }
}