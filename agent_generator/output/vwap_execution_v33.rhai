let target_qty = 100000;
let total_filled = 0;
let volume_ma = 0;
let volume_window = [];
let window_size = 20;
let last_action_tick = -1000;
let slice_base = 10000;
let price_offset = 1;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    let i = 0;
    while i < my_orders.fill_count() {
        let fill_side = my_orders.fill_side(i);
        if fill_side == 0 {
            total_filled += my_orders.fill_amount(i);
        }
        i += 1;
    }
    
    volume_window.push(market.volume);
    if volume_window.len() > window_size {
        volume_window.remove(0);
    }
    
    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }
    
    if total_filled >= target_qty { return; }
    
    if market.tick - last_action_tick < 5 { return; }
    
    if volume_window.len() >= window_size {
        let vol_sum = 0;
        let k = 0;
        while k < volume_window.len() {
            vol_sum += volume_window[k];
            k += 1;
        }
        volume_ma = vol_sum / volume_window.len();
    } else {
        volume_ma = market.volume;
    }
    
    let slice = 0;
    if volume_ma > 0 {
        let volume_ratio = market.volume * 10000 / volume_ma;
        let adjusted_slice = slice_base * volume_ratio / 10000;
        slice = clamp_val(adjusted_slice, 1000, 50000);
    } else {
        slice = slice_base;
    }
    
    let remaining = target_qty - total_filled;
    let order_amount = slice;
    if order_amount > remaining {
        order_amount = remaining;
    }
    if order_amount <= 0 { return; }
    
    let target_price = market.vwap + price_offset;
    if market.bid_price_0 < target_price && order_amount > 0 {
        orders.submit_limit_buy(target_price, order_amount);
        last_action_tick = market.tick;
    }
}