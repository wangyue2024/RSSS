let initialized = false;
let total_target = 0;
let remaining_target = 0;
let low_vol_threshold = 0;
let high_vol_threshold = 0;
let min_slice = 0;
let max_slice = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        total_target = 10000;
        remaining_target = total_target;
        low_vol_threshold = 5000;
        high_vol_threshold = 20000;
        min_slice = 100;
        max_slice = 1000;
    }
    
    if !market.trading_enabled { return; }
    
    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        if my_orders.fill_side(i) == 0 {
            remaining_target = remaining_target - my_orders.fill_amount(i);
        }
        i += 1;
    }
    
    if remaining_target <= 0 { return; }
    
    let pending_cnt = my_orders.pending_count();
    i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let recent_volumes = [];
    let lookback = 20;
    let j = 0;
    while j < lookback && j < market.history_len() {
        recent_volumes.push(market.history_volume(j));
        j += 1;
    }
    
    let recent_avg_volume = 0;
    if recent_volumes.len() > 0 {
        recent_avg_volume = arr_mean(recent_volumes);
    }
    
    let volume_factor = 0;
    if recent_avg_volume > low_vol_threshold {
        volume_factor = (recent_avg_volume - low_vol_threshold) * 100 / (high_vol_threshold - low_vol_threshold);
        if volume_factor > 100 { volume_factor = 100; }
    }
    
    let slice = min_slice + (volume_factor * (max_slice - min_slice)) / 100;
    if slice > remaining_target {
        slice = remaining_target;
    }
    
    if slice <= 0 { return; }
    
    let current_price = market.price;
    let round_price = (current_price + 500_000) / 1_000_000 * 1_000_000;
    let limit_price = round_price;
    if limit_price >= current_price {
        limit_price = limit_price - 1_000_000;
    }
    if limit_price < 1_000_000 {
        limit_price = 1_000_000;
    }
    
    orders.submit_limit_buy(limit_price, slice);
}