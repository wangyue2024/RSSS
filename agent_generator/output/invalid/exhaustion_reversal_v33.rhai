// Global variables persist across ticks
let order_ids = [];
let order_placed_ticks = [];

fn on_tick() {
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    // Cancel orders older than 3 ticks
    let i = 0;
    while i < order_ids.len() {
        let age = current_tick - order_placed_ticks[i];
        if age > 3 {
            let oid = order_ids[i];
            orders.submit_cancel(oid);
            order_ids.remove(i);
            order_placed_ticks.remove(i);
        } else {
            i += 1;
        }
    }
    
    // Check if we have enough history
    if market.history_len() < 5 { return; }
    if market.ma_60 == 0 { return; }
    
    // Calculate volume condition: current volume < 10% of 5-period average
    let vol_arr = [];
    let start_idx = market.history_len() - 5;
    let idx = start_idx;
    while idx < market.history_len() {
        vol_arr.push(market.history_volume(idx));
        idx += 1;
    }
    let avg_vol = arr_mean(vol_arr);
    let volume_threshold = avg_vol * 10 / 100;
    let volume_condition = market.volume < volume_threshold;
    
    // Calculate price condition: price > ma_60 by at least 1%
    let price_above_ma = market.price - market.ma_60;
    let percent_above = price_above_ma * 100 / market.ma_60;
    let price_condition = percent_above >= 1;
    
    // Exhaustion reversal signal
    if volume_condition && price_condition {
        // Check if we have stock to sell
        let sell_amount = 100;
        if account.stock >= sell_amount {
            let sell_price = market.bid_price_0;
            if sell_price > 0 {
                orders.submit_limit_sell(sell_price, sell_amount);
                // Track this new order
                let pending_count = my_orders.pending_count();
                if pending_count > 0 {
                    // Get the last pending order (most recently placed)
                    let last_idx = pending_count - 1;
                    let new_id = my_orders.pending_id(last_idx);
                    order_ids.push(new_id);
                    order_placed_ticks.push(current_tick);
                }
            }
        }
    }
}