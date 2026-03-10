let price_history = [];
let volume_history = [];
let initialized = false;
let target_units = 5000;
let bought_so_far = 0;
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    let current_volume = market.volume;
    
    price_history.push(current_price);
    volume_history.push(current_volume);
    
    if price_history.len() > 100 {
        price_history.remove(0);
    }
    if volume_history.len() > 100 {
        volume_history.remove(0);
    }
    
    let fill_count = my_orders.fill_count();
    let i = 0;
    while i < fill_count {
        let fill_side = my_orders.fill_side(i);
        let fill_amount = my_orders.fill_amount(i);
        if fill_side == 0 {
            bought_so_far += fill_amount;
        }
        i += 1;
    }
    
    let remaining_to_buy = target_units - bought_so_far;
    if remaining_to_buy <= 0 {
        let pending_count = my_orders.pending_count();
        let j = 0;
        while j < pending_count {
            let oid = my_orders.pending_id(j);
            orders.submit_cancel(oid);
            j += 1;
        }
        return;
    }
    
    if price_history.len() < 10 {
        return;
    }
    
    let delayed_index = price_history.len() - 6;
    if delayed_index < 0 {
        return;
    }
    
    let delayed_price = price_history[delayed_index];
    let delayed_volume = volume_history[delayed_index];
    
    let recent_volumes = [];
    let start_idx = if volume_history.len() > 20 { volume_history.len() - 20 } else { 0 };
    let k = start_idx;
    while k < volume_history.len() - 5 {
        recent_volumes.push(volume_history[k]);
        k += 1;
    }
    
    if recent_volumes.len() == 0 {
        return;
    }
    
    let avg_recent_volume = arr_mean(recent_volumes);
    let volume_ratio = if avg_recent_volume > 0 {
        (delayed_volume * 100) / avg_recent_volume
    } else {
        100
    };
    
    let base_slice = 50;
    let volume_adjusted = (base_slice * volume_ratio) / 100;
    let slice_size = clamp_val(volume_adjusted, 10, 200);
    
    let check_fomo_index = delayed_index - 2;
    if check_fomo_index >= 0 {
        let price_old = price_history[check_fomo_index];
        let price_change = abs_val(delayed_price - price_old) * 10000 / price_old;
        if price_change > 200 {
            fomo_triggered = true;
        }
    }
    
    let pending_count = my_orders.pending_count();
    let j = 0;
    while j < pending_count {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }
    
    if fomo_triggered {
        if remaining_to_buy > 0 {
            let buy_amount = if remaining_to_buy > 500 { 500 } else { remaining_to_buy };
            orders.submit_market_buy(buy_amount);
        }
        return;
    }
    
    if remaining_to_buy > 0 {
        let order_amount = if slice_size > remaining_to_buy { remaining_to_buy } else { slice_size };
        if order_amount > 0 {
            orders.submit_limit_buy(delayed_price, order_amount);
        }
    }
}