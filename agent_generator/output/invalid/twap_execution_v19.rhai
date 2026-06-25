// Global variables persist across ticks automatically
let initialized = false;
let price_history = [];
let last_action_tick = -1000;
let target_position = 50_000;
let lot_size = 0;
let interval_ticks = 0;

fn on_tick() {
    // Delayed Reaction: Save current price to history
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if !initialized {
        initialized = true;
        // Heavily Risk-Seeking: large lot_size using 50% of cash
        let risk_factor = rng.rand_int(40, 60); // 40-60% of cash
        let available_shares = account.cash * risk_factor / (100 * market.price);
        lot_size = rng.rand_int(available_shares / 2, available_shares);
        if lot_size < 100 { lot_size = 100; }
        interval_ticks = rng.rand_int(1, 3); // Trade very frequently
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel any pending orders (safety)
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Only react to data that is 5 ticks old
    if price_history.len() >= 5 {
        let delayed_price = price_history[0];
        
        // Check if we need to accumulate more
        if account.stock < target_position {
            // Check if enough ticks have passed since last action
            if (market.tick - last_action_tick) >= interval_ticks {
                let remaining = target_position - account.stock;
                let amount = if lot_size < remaining { lot_size } else { remaining };
                if amount > 0 {
                    orders.submit_market_buy(amount);
                    last_action_tick = market.tick;
                }
            }
        }
    }
}