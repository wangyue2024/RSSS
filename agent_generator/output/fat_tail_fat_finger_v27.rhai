let initialized = false;
let base_lot_size = 0;
let fat_finger_chance = 1;
let std_dev_threshold = 50_000;

fn on_tick() {
    if !initialized {
        if !market.trading_enabled { return; }
        
        let five_percent_capital = account.total_equity * 5 / 100;
        let price = market.price;
        if price == 0 { return; }
        
        let max_lot = five_percent_capital / price;
        if max_lot < 1 {
            base_lot_size = 1;
        } else {
            base_lot_size = rng.rand_int(1, max_lot);
        }
        
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.std_dev > std_dev_threshold {
        return;
    }
    
    if rng.rand_int(0, 9999) < fat_finger_chance {
        let fat_amount = base_lot_size * 100;
        let is_buy = rng.rand_bool(50);
        
        if is_buy {
            orders.submit_market_buy(fat_amount);
        } else {
            orders.submit_market_sell(fat_amount);
        }
    }
}