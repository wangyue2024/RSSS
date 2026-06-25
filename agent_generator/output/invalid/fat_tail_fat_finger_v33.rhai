let initialized = false;
let base_amount = 0;
let fat_finger_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_amount = rng.rand_int(100, 1000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if rng.rand_int(0, 9999) == 0 {
        fat_finger_triggered = true;
        let fat_amount = base_amount * 100;
        
        if rng.rand_bool(50) {
            orders.submit_market_buy(fat_amount);
        } else {
            orders.submit_market_sell(fat_amount);
        }
        return;
    }
    
    fat_finger_triggered = false;
    
    let normal_trade = rng.rand_int(0, 99) == 0;
    
    if normal_trade {
        if rng.rand_bool(50) {
            let bid_price = market.bid_price_0 + 1;
            if bid_price > 0 && account.cash > bid_price {
                orders.submit_limit_buy(bid_price, base_amount);
            }
        } else if account.stock > 0 && market.price > account.avg_cost {
            let ask_price = market.ask_price_0;
            if ask_price > 0 {
                orders.submit_limit_sell(ask_price, base_amount);
            }
        }
    }
}