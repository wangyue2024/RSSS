let initialized = false;
let price_history = [];
let volume_history = [];
let pending_ticks = [];
let target_position = 50_000;
let current_target = 0;
let base_slice = 0;
let slices_completed = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        current_target = target_position;
        base_slice = rng.rand_int(100, 500);
    }

    if !market.trading_enabled { return; }

    price_history.push(market.price);
    volume_history.push(market.volume);
    
    if price_history.len() > 6 {
        price_history.remove(0);
    }
    if volume_history.len() > 6 {
        volume_history.remove(0);
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if price_history.len() < 6 || volume_history.len() < 6 {
        return;
    }

    let delayed_price = price_history[0];
    let delayed_volume = volume_history[0];
    
    let recent_avg_volume = (volume_history[1] + volume_history[2] + volume_history[3] + volume_history[4] + volume_history[5]) / 5;
    
    let volume_ratio = if recent_avg_volume > 0 {
        (delayed_volume * 10000) / recent_avg_volume
    } else {
        10000
    };
    
    let slice_size = if volume_ratio > 12000 {
        base_slice * 3 / 2
    } else if volume_ratio < 8000 {
        base_slice * 1 / 2
    } else {
        base_slice
    };
    
    let remaining_to_buy = current_target - account.stock;
    if remaining_to_buy <= 0 { return; }
    
    let this_slice = if slice_size > remaining_to_buy { remaining_to_buy } else { slice_size };
    
    if this_slice > 0 {
        let bid_price = delayed_price + 1;
        orders.submit_limit_buy(bid_price, this_slice);
    }
}