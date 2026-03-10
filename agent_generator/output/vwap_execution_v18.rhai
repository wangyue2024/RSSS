let initialized = false;
let total_target = 0;
let total_bought = 0;
let last_order_ticks = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        total_target = rng.rand_int(5000, 15000);
        total_bought = 0;
        last_order_ticks = [];
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    if current_tick >= market.total_ticks / 5 {
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let remaining_target = total_target - total_bought;
    if remaining_target <= 0 { return; }
    
    let recent_volumes = [];
    let lookback = 10;
    let i = 0;
    while i < lookback && i < market.history_len() {
        recent_volumes.push(market.history_volume(i));
        i += 1;
    }
    
    let avg_volume = 0;
    if recent_volumes.len() > 0 {
        avg_volume = arr_mean(recent_volumes);
    }
    
    if avg_volume == 0 { return; }
    
    let volume_ratio = market.volume * 100 / avg_volume;
    let slice_size = 0;
    
    if volume_ratio > 150 {
        slice_size = remaining_target * 30 / 100;
    } else if volume_ratio > 120 {
        slice_size = remaining_target * 20 / 100;
    } else if volume_ratio > 90 {
        slice_size = remaining_target * 15 / 100;
    } else {
        slice_size = remaining_target * 10 / 100;
    }
    
    slice_size = clamp_val(slice_size, 100, remaining_target);
    
    let pending_count = my_orders.pending_count();
    let j = 0;
    while j < pending_count {
        let placed_tick = my_orders.pending_placed_tick(j);
        if current_tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(j);
            orders.submit_cancel(oid);
        }
        j += 1;
    }
    
    let fill_cnt = my_orders.fill_count();
    let k = 0;
    while k < fill_cnt {
        let fill_side = my_orders.fill_side(k);
        if fill_side == 0 {
            total_bought += my_orders.fill_amount(k);
        }
        k += 1;
    }
    
    remaining_target = total_target - total_bought;
    if remaining_target <= 0 { return; }
    
    slice_size = clamp_val(slice_size, 100, remaining_target);
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let order_price = mid_price - 1000;
    
    if slice_size > 0 && market.bid_price_0 > 0 {
        orders.submit_limit_buy(order_price, slice_size);
        last_order_ticks.push(current_tick);
    }
}