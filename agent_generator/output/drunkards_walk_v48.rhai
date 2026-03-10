let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Only trade during first 20% of session
    if market.tick >= market.total_ticks * 20 / 100 {
        return;
    }
    
    // Cancel any pending orders older than 3 ticks
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Random trade decision
    let roll = rng.rand_int(0, 99);
    
    if roll < 5 {
        // Random buy
        let amount = rng.rand_int(1, 100);
        let price_offset = rng.rand_int(-5000, 5000); // Random offset in micros
        let price = market.price + price_offset;
        if price > 0 {
            orders.submit_limit_buy(price, amount);
        }
    } else if roll > 95 {
        // Random sell
        let amount = rng.rand_int(1, 100);
        let price_offset = rng.rand_int(-5000, 5000); // Random offset in micros
        let price = market.price + price_offset;
        if price > 0 {
            orders.submit_limit_sell(price, amount);
        }
    }
}