// Global variables persist across ticks
let target_amount = 10000;
let accumulated = 0;
let initialized = false;
let lookback_period = 20;
let base_slice_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_slice_size = rng.rand_int(50, 200);
    }
    
    if !market.trading_enabled { return; }
    
    // Process fills from last tick
    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        if my_orders.fill_side(i) == 0 {
            accumulated += my_orders.fill_amount(i);
        }
        i += 1;
    }
    
    // Cancel orders pending >= 3 ticks
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed = my_orders.pending_placed_tick(i);
        if market.tick - placed >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Check if target reached
    if accumulated >= target_amount {
        return;
    }
    
    // Calculate volume ratio for dynamic slicing
    let recent_volume = 0;
    let avg_volume = 0;
    let history_len = market.history_len();
    
    if history_len >= lookback_period {
        // Calculate recent volume (last 5 ticks)
        let recent_sum = 0;
        let j = 0;
        while j < 5 && j < history_len {
            recent_sum += market.history_volume(j);
            j += 1;
        }
        recent_volume = recent_sum / 5;
        
        // Calculate average volume over lookback period
        let total_sum = 0;
        let k = 0;
        while k < lookback_period && k < history_len {
            total_sum += market.history_volume(k);
            k += 1;
        }
        avg_volume = total_sum / lookback_period;
    } else {
        // Not enough history yet
        recent_volume = market.volume;
        avg_volume = market.volume;
    }
    
    // Determine slice size based on volume activity
    let remaining = target_amount - accumulated;
    let volume_ratio = 100;
    if avg_volume > 0 {
        volume_ratio = (recent_volume * 100) / avg_volume;
    }
    
    // Calculate dynamic slice (capped at remaining)
    let dynamic_slice = base_slice_size * volume_ratio / 100;
    let slice_size = dynamic_slice;
    if slice_size < 10 { slice_size = 10; }
    if slice_size > remaining { slice_size = remaining; }
    
    // Only place order if we have a valid slice
    if slice_size > 0 && market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        // Place limit buy at best bid
        let buy_price = market.bid_price_0;
        orders.submit_limit_buy(buy_price, slice_size);
    }
}