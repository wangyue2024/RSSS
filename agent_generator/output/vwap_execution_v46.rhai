let initialized = false;
let total_target = 0;
let remaining = 0;
let panic_mode = false;
let panic_trigger_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        total_target = 5000;
        remaining = total_target;
    }
    
    if !market.trading_enabled { return; }
    
    // Update remaining from fills
    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        if my_orders.fill_side(i) == 0 {
            remaining = remaining - my_orders.fill_amount(i);
        }
        i += 1;
    }
    
    // FOMO Check: price jump > 2% in last 5 ticks
    if market.history_len() >= 5 {
        let old_price = market.history_price(4);
        let change_pct = (market.price - old_price) * 10000 / old_price;
        if change_pct > 200 && !panic_mode {
            panic_mode = true;
            panic_trigger_price = market.price;
        }
    }
    
    // Cancel all pending orders on any major action
    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(j));
        j += 1;
    }
    
    if remaining <= 0 { return; }
    
    // FOMO Execution
    if panic_mode {
        let buy_amount = remaining;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        panic_mode = false;
        return;
    }
    
    // Dynamic VWAP Slicing
    let avg_volume = 0;
    let hist_len = market.history_len();
    if hist_len > 0 {
        let sum = 0;
        let k = 0;
        while k < hist_len && k < 20 {
            sum = sum + market.history_volume(k);
            k += 1;
        }
        avg_volume = sum / k;
    }
    
    let current_vol = market.volume;
    let volume_ratio = 100;
    if avg_volume > 0 {
        volume_ratio = current_vol * 100 / avg_volume;
    }
    
    let base_slice = total_target * 10 / 100;
    let dynamic_slice = base_slice * volume_ratio / 100;
    dynamic_slice = clamp_val(dynamic_slice, 10, 1000);
    dynamic_slice = clamp_val(dynamic_slice, 0, remaining);
    
    if dynamic_slice > 0 {
        let limit_price = market.price;
        orders.submit_limit_buy(limit_price, dynamic_slice);
    }
}