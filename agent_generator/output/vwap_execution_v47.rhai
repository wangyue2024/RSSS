// Global state
let total_target = 100_000_000; // 100 dollars worth in micros
let total_bought = 0;
let last_decision_tick = -100;
let pending_order_id = -1;
let is_initialized = false;

fn on_tick() {
    // Initialize once
    if !is_initialized {
        is_initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Process fills to update total_bought
    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        let side = my_orders.fill_side(i);
        if side == 0 { // buy fill
            let price = my_orders.fill_price(i);
            let amount = my_orders.fill_amount(i);
            total_bought += price * amount;
        }
        i += 1;
    }
    
    // Lazy trader: only act every 50 ticks
    if market.tick - last_decision_tick < 50 { return; }
    last_decision_tick = market.tick;
    
    // Cancel existing pending order
    if pending_order_id >= 0 {
        orders.submit_cancel(pending_order_id);
        pending_order_id = -1;
    }
    
    // Check if target reached
    if total_bought >= total_target { return; }
    
    // Calculate remaining to buy
    let remaining_value = total_target - total_bought;
    if remaining_value <= 0 { return; }
    
    // Get recent volume (last 20 ticks)
    let lookback = 20;
    let available = market.history_len();
    let count = if lookback < available { lookback } else { available };
    let total_volume = 0;
    let j = 0;
    while j < count {
        total_volume += market.history_volume(j);
        j += 1;
    }
    let avg_volume = if count > 0 { total_volume / count } else { 1000 };
    
    // Dynamic sizing: higher volume -> larger slice
    let volume_factor = clamp_val(avg_volume, 1000, 10000);
    let slice_value = remaining_value * volume_factor / 10000;
    let slice_value = clamp_val(slice_value, 1_000_000, 10_000_000);
    
    // Convert to shares at current price
    if market.price == 0 { return; }
    let shares_to_buy = slice_value / market.price;
    if shares_to_buy <= 0 { return; }
    
    // Round price to nearest dollar (1,000,000 micros)
    let raw_price = market.price;
    let rounded_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
    
    // Place limit buy at rounded price
    let order_id = orders.submit_limit_buy(rounded_price, shares_to_buy);
    if order_id >= 0 {
        pending_order_id = order_id;
    }
}