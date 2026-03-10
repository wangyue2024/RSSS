let initialized = false;
let target_shares = 0;
let shares_bought = 0;
let price_buffer = [];
let volume_buffer = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        target_shares = rng.rand_int(500, 2000);
        shares_bought = 0;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    price_buffer.push(market.price);
    volume_buffer.push(market.volume);
    
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
        volume_buffer.remove(0);
    }
    
    if fomo_triggered {
        let remaining = target_shares - shares_bought;
        if remaining > 0 {
            orders.submit_market_buy(remaining);
        }
        return;
    }
    
    if price_buffer.len() == 5 {
        let old_price = price_buffer[0];
        let price_change = (market.price - old_price) * 100 / old_price;
        
        if price_change > 200 {
            fomo_triggered = true;
            let remaining = target_shares - shares_bought;
            if remaining > 0 {
                orders.submit_market_buy(remaining);
            }
            return;
        }
        
        let recent_volume = arr_mean(volume_buffer);
        let volume_ratio = clamp_val(recent_volume * 100 / 10000, 50, 200);
        
        let base_slice = target_shares / 20;
        let dynamic_slice = base_slice * volume_ratio / 100;
        
        let remaining_target = target_shares - shares_bought;
        let slice_size = clamp_val(dynamic_slice, 10, remaining_target);
        
        if slice_size > 0 {
            let order_price = market.bid_price_0 - micros(0, 1);
            orders.submit_limit_buy(order_price, slice_size);
        }
    }
    
    let fill_cnt = my_orders.fill_count();
    let j = 0;
    while j < fill_cnt {
        if my_orders.fill_side(j) == 1 {
            shares_bought += my_orders.fill_amount(j);
        }
        j += 1;
    }
}