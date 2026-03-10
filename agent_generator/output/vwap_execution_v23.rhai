let initialized = false;
let target_shares = 10000;
let remaining_shares = target_shares;
let base_slice_percent = 100;  // 1% of target
let lookback_ticks = 20;

fn on_tick() {
    if !initialized {
        remaining_shares = target_shares;
        // Cancel any existing orders from previous run
        let pending_cnt = my_orders.pending_count();
        for i in 0..pending_cnt {
            let oid = my_orders.pending_id(pending_cnt - 1 - i);
            orders.submit_cancel(oid);
        }
        initialized = true;
    }
    
    if !market.trading_enabled || remaining_shares <= 0 { return; }
    
    // Process fills from last tick
    let fill_cnt = my_orders.fill_count();
    for i in 0..fill_cnt {
        if my_orders.fill_side(i) == 0 {
            let fill_amt = my_orders.fill_amount(i);
            if fill_amt > remaining_shares {
                remaining_shares = 0;
            } else {
                remaining_shares -= fill_amt;
            }
        }
    }
    
    if remaining_shares <= 0 { return; }
    
    // Cancel stale orders
    let pending_cnt = my_orders.pending_count();
    for i in 0..pending_cnt {
        let oid = my_orders.pending_id(pending_cnt - 1 - i);
        orders.submit_cancel(oid);
    }
    
    // Calculate average volume over lookback period
    let hist_len = market.history_len();
    let used_lookback = if hist_len < lookback_ticks { hist_len } else { lookback_ticks };
    let total_vol = 0;
    for idx in 0..used_lookback {
        total_vol += market.history_volume(idx);
    }
    let avg_vol = if used_lookback > 0 { total_vol / used_lookback } else { market.volume };
    
    // Dynamic slicing based on volume
    let volume_ratio = if avg_vol > 0 { market.volume * 100 / avg_vol } else { 100 };
    let base_slice = target_shares * base_slice_percent / 10000;
    let slice = base_slice * volume_ratio / 100;
    
    // Clamp slice to reasonable bounds
    let min_slice = 1;
    let max_slice = remaining_shares * 200 / 1000;  // Max 20% of remaining
    if slice < min_slice { slice = min_slice; }
    if slice > max_slice { slice = max_slice; }
    if slice > remaining_shares { slice = remaining_shares; }
    
    // Calculate price - use VWAP if available, else mid-price
    let price_base = if market.vwap > 0 { market.vwap } else {
        if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
            (market.bid_price_0 + market.ask_price_0) / 2
        } else {
            market.price
        }
    };
    
    // Off-by-One Pumper: add 1 micro to jump queue
    let bid_price = price_base + 1;
    
    // Submit order
    orders.submit_limit_buy(bid_price, slice);
}