let initialized = false;
let target_shares = 0;
let remaining_buy = 0;
let round_bias = 1_000_000;

fn on_tick() {
    if !initialized {
        initialized = true;
        target_shares = 5000;
        remaining_buy = target_shares;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fill_cnt = my_orders.fill_count();
    i = 0;
    while i < fill_cnt {
        if my_orders.fill_side(i) == 0 {
            remaining_buy -= my_orders.fill_amount(i);
        }
        i += 1;
    }
    
    if remaining_buy <= 0 { return; }
    
    let current_vol = market.volume;
    let lookback = 20;
    let available_hist = market.history_len();
    let calc_ticks = if available_hist < lookback { available_hist } else { lookback };
    
    let vol_sum = current_vol;
    let j = 0;
    while j < calc_ticks {
        vol_sum += market.history_volume(j);
        j += 1;
    }
    
    let avg_vol = vol_sum / (calc_ticks + 1);
    let slice_pct = if current_vol > avg_vol { 15 } else { 5 };
    let slice_size = (remaining_buy * slice_pct) / 100;
    
    if slice_size <= 0 { return; }
    
    let raw_price = market.price;
    let rounded_price = ((raw_price + 500_000) / round_bias) * round_bias;
    
    orders.submit_limit_buy(rounded_price, slice_size);
}