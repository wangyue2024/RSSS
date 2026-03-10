let initialized = false;
let target_shares = 0;
let shares_bought = 0;
let base_order_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        target_shares = rng.rand_int(800, 1200);
        base_order_size = rng.rand_int(5, 15);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let fill_cnt = my_orders.fill_count();
    let f = 0;
    while f < fill_cnt {
        if my_orders.fill_side(f) == 0 {
            shares_bought += my_orders.fill_amount(f);
        }
        f += 1;
    }
    
    if shares_bought >= target_shares {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }
    
    let hist_len = market.history_len();
    if hist_len == 0 { return; }
    
    let recent_vol = 0;
    let i = 0;
    while i < 5 && i < hist_len {
        recent_vol += market.history_volume(i);
        i += 1;
    }
    let recent_avg_vol = recent_vol / 5;
    
    let volume_factor = recent_avg_vol * 100 / 1_000_000;
    let volume_factor = clamp_val(volume_factor, 50, 200);
    
    let order_amount = base_order_size * volume_factor / 100;
    if order_amount < 1 { order_amount = 1; }
    let remaining = target_shares - shares_bought;
    if order_amount > remaining { order_amount = remaining; }
    
    let raw_price = market.bid_price_0;
    if raw_price == 0 { raw_price = market.price; }
    
    let rounded_price = (raw_price + 500_000) / 1_000_000 * 1_000_000;
    let order_price = rounded_price + 1;
    
    if order_amount > 0 {
        orders.submit_limit_buy(order_price, order_amount);
    }
}