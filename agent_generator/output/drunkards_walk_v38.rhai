let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all existing orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Generate random decision
    let rand_val = rng.rand_int(0, 99);
    
    if rand_val < 5 {
        // Random buy
        let qty = rng.rand_int(1, 100);
        let price_offset = rng.rand_int(-50, 50);
        let target_price = market.price + price_offset;
        if target_price < 1 { target_price = 1; }
        // Off-by-One Pumper quirk: add 1 micro to bid price
        orders.submit_limit_buy(target_price + 1, qty);
    } else if rand_val > 95 {
        // Random sell
        let qty = rng.rand_int(1, 100);
        let price_offset = rng.rand_int(-50, 50);
        let target_price = market.price + price_offset;
        if target_price < 1 { target_price = 1; }
        orders.submit_limit_sell(target_price, qty);
    }
}