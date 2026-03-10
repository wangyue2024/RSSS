let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let rand_val = rng.rand_int(0, 99);
    
    if rand_val < 5 {
        let qty = rng.rand_int(1, 100);
        let offset = rng.rand_int(-100, 100);
        let price = market.price + offset + 1;
        if price < 1 { price = 1; }
        orders.submit_limit_buy(price, qty);
    } else if rand_val > 95 {
        let qty = rng.rand_int(1, 100);
        let offset = rng.rand_int(-100, 100);
        let price = market.price + offset;
        if price < 1 { price = 1; }
        orders.submit_limit_sell(price, qty);
    }
}