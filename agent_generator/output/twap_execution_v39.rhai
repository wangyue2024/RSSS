let initialized = false;
let target_position = 0;
let slice_size = 0;
let interval_ticks = 0;
let next_buy_tick = 0;
let my_impatience_ticks = 3;

fn on_tick() {
    if !initialized {
        // Initialize strategy parameters
        target_position = 50_000;
        slice_size = 500;
        interval_ticks = 5;
        next_buy_tick = 0;
        my_impatience_ticks = 3;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    // Cancel any pending limit orders older than impatience threshold
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let order_tick = my_orders.pending_placed_tick(i);
        if current_tick - order_tick > my_impatience_ticks {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Check if we need to buy more
    if account.stock >= target_position {
        return;
    }
    
    // Check if it's time for the next slice
    if current_tick >= next_buy_tick {
        let amount_needed = target_position - account.stock;
        if amount_needed <= 0 {
            return;
        }
        
        let buy_amount = if slice_size > amount_needed { amount_needed } else { slice_size };
        
        // Submit market buy order for this slice
        orders.submit_market_buy(buy_amount);
        
        // Schedule next buy
        next_buy_tick = current_tick + interval_ticks;
    }
}