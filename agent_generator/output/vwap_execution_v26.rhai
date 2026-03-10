// Global variables persist across ticks automatically
let total_target = 100_000;
let remaining_target = total_target;
let last_action_tick = -100;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Update remaining target from any fills this tick
    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        if my_orders.fill_side(i) == 0 { // 0 is buy fill
            remaining_target = remaining_target - my_orders.fill_amount(i);
            if remaining_target < 0 {
                remaining_target = 0;
            }
        }
        i += 1;
    }
    
    // Lazy trader: only evaluate every 50 ticks
    if market.tick - last_action_tick < 50 {
        return;
    }
    
    // Cancel any existing pending orders
    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }
    
    // If we've already bought our target, do nothing
    if remaining_target <= 0 {
        return;
    }
    
    // Calculate recent volume average (last 20 ticks)
    let lookback = 20;
    let available = market.history_len();
    let actual_lookback = if available < lookback { available } else { lookback };
    
    if actual_lookback == 0 {
        last_action_tick = market.tick;
        return;
    }
    
    let vol_sum = 0;
    let idx = 0;
    while idx < actual_lookback {
        vol_sum = vol_sum + market.history_volume(idx);
        idx += 1;
    }
    let avg_volume = vol_sum / actual_lookback;
    
    // Determine slice size based on current volume vs average
    let base_slice = 500; // Base order size
    let volume_ratio = 0;
    if avg_volume > 0 {
        volume_ratio = (market.volume * 100) / avg_volume;
    } else {
        volume_ratio = 100;
    }
    
    // Scale order size: high volume = bigger slice
    let raw_slice = (base_slice * volume_ratio) / 100;
    let slice = clamp_val(raw_slice, 100, 5000);
    
    // Don't exceed remaining target
    let order_amount = if slice > remaining_target { remaining_target } else { slice };
    
    if order_amount <= 0 {
        last_action_tick = market.tick;
        return;
    }
    
    // Off-by-one pumper: VWAP plus 1 micro
    let bid_price = market.vwap + 1;
    
    // Place limit buy order
    orders.submit_limit_buy(bid_price, order_amount);
    
    // Update last action tick
    last_action_tick = market.tick;
}