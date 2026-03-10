let initialized = false;
let morning_only = true;
let risk_seeking = false;
let total_target_shares = 0;
let shares_acquired = 0;
let max_position_size = 0;
let base_slice_size = 0;
let volume_lookback = 20;
let std_dev_threshold = 0;
let last_cancel_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        morning_only = true;
        risk_seeking = rng.rand_bool(50);
        
        if risk_seeking {
            max_position_size = account.cash * 50 / 100;
            std_dev_threshold = market.price * 10 / 100;
        } else {
            max_position_size = account.cash * 5 / 100;
            std_dev_threshold = market.price * 2 / 100;
        }
        
        total_target_shares = max_position_size / market.price;
        if total_target_shares < 1 { total_target_shares = 1; }
        
        base_slice_size = total_target_shares / 100;
        if base_slice_size < 1 { base_slice_size = 1; }
        
        last_cancel_tick = market.tick;
    }
    
    if !market.trading_enabled { return; }
    
    if morning_only && market.tick >= market.total_ticks * 1 / 5 {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    if market.std_dev > std_dev_threshold {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    if market.tick - last_cancel_tick > 10 {
        last_cancel_tick = market.tick;
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
    }
    
    let fill_count = my_orders.fill_count();
    let i = 0;
    while i < fill_count {
        let fill_side = my_orders.fill_side(i);
        if fill_side == 0 {
            shares_acquired += my_orders.fill_amount(i);
        }
        i += 1;
    }
    
    if shares_acquired >= total_target_shares {
        return;
    }
    
    let remaining_shares = total_target_shares - shares_acquired;
    if remaining_shares <= 0 {
        return;
    }
    
    let hist_len = market.history_len();
    let lookback = if volume_lookback > hist_len { hist_len } else { volume_lookback };
    
    let avg_volume = 0;
    if lookback > 0 {
        let j = 0;
        while j < lookback {
            avg_volume += market.history_volume(j);
            j += 1;
        }
        avg_volume = avg_volume / lookback;
    } else {
        avg_volume = market.volume;
    }
    
    let volume_ratio = 100;
    if avg_volume > 0 {
        volume_ratio = market.volume * 100 / avg_volume;
    }
    
    let dynamic_slice = base_slice_size * volume_ratio / 100;
    if dynamic_slice < 1 { dynamic_slice = 1; }
    
    let order_size = if dynamic_slice > remaining_shares { remaining_shares } else { dynamic_slice };
    
    if order_size <= 0 {
        return;
    }
    
    let spread = market.ask_price_0 - market.bid_price_0;
    let price_adjustment = spread * 30 / 100;
    let limit_price = market.bid_price_0 + price_adjustment;
    
    if limit_price <= 0 {
        return;
    }
    
    let pending_buy_value = 0;
    let pending_count = my_orders.pending_count();
    let j = 0;
    while j < pending_count {
        let side = my_orders.pending_side(j);
        if side == 0 {
            pending_buy_value += my_orders.pending_price(j) * my_orders.pending_amount(j);
        }
        j += 1;
    }
    
    let current_buy_power = account.cash - pending_buy_value;
    let order_value = limit_price * order_size;
    
    if current_buy_power >= order_value && order_size > 0 {
        orders.submit_limit_buy(limit_price, order_size);
    }
}