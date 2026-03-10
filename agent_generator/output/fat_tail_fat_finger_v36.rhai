let initialized = false;
let normal_order_size = 100;

fn on_tick() {
    if !initialized {
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
    
    let fat_finger_chance = rng.rand_int(0, 9999);
    
    if fat_finger_chance == 0 {
        let fat_finger_size = normal_order_size * 100;
        
        if rng.rand_bool(50) {
            let max_buy = account.cash / market.price;
            let buy_amount = fat_finger_size;
            if max_buy < buy_amount {
                buy_amount = max_buy;
            }
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        } else {
            let sell_amount = fat_finger_size;
            if account.stock < sell_amount {
                sell_amount = account.stock;
            }
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
            }
        }
    }
}