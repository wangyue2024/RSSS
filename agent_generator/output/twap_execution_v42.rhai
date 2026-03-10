let initialized = false;
let target_shares = 50000;
let slice_size = 500;
let interval_ticks = 10;
let next_order_tick = 0;
let total_accumulated = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        next_order_tick = market.tick + interval_ticks;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel any pending orders to avoid duplicates
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Check if we need to accumulate more
    if total_accumulated >= target_shares { return; }
    
    // Place order at interval
    if market.tick >= next_order_tick {
        let remaining = target_shares - total_accumulated;
        let order_amount = if slice_size > remaining { remaining } else { slice_size };
        
        if order_amount > 0 {
            // Calculate round price (nearest 1,000,000 micros)
            let half_dollar = 500000;
            let round_price = ((market.price + half_dollar) / 1_000_000) * 1_000_000;
            
            orders.submit_limit_buy(round_price, order_amount);
            total_accumulated += order_amount;
        }
        
        next_order_tick = market.tick + interval_ticks;
    }
}