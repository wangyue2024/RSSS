// Global variables persist across ticks
let recent_prices = [];
let last_fomo_buy_tick = -1000;
let base_position_size = 1000;
let initialized = false;

fn on_tick() {
    if (!initialized) {
        initialized = true;
        // Initialize with some randomness for order size variation
        base_position_size = rng.rand_int(800, 1200);
    }
    
    if (!market.trading_enabled) { return; }
    
    // Cancel all pending orders each tick for clean slate
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while (i < pending_cnt) {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    // --- FOMO CONDITION: Check for 2% jump in last 5 ticks ---
    // Maintain recent prices array (max 6 elements)
    recent_prices.push(market.price);
    if (recent_prices.len() > 6) {
        recent_prices.remove(0);
    }
    
    let fomo_triggered = false;
    if (recent_prices.len() >= 5) {
        let old_price = recent_prices[0];
        if (old_price > 0) {
            // Check if current price is >2% higher than price 5 ticks ago
            // 2% = price * 2 / 100, but we're comparing difference
            let jump_threshold = old_price * 2 / 100; // 2% of old price
            if ((market.price - old_price) > jump_threshold) {
                fomo_triggered = true;
            }
        }
    }
    
    // FOMO override: if price jumped >2%, market buy immediately
    if (fomo_triggered && (market.tick - last_fomo_buy_tick) > 10) {
        last_fomo_buy_tick = market.tick;
        // Buy with available cash (limit to 1000 shares max)
        let max_affordable = account.cash / market.price;
        let buy_amount = arr_min([max_affordable, base_position_size]);
        if (buy_amount > 0) {
            orders.submit_market_buy(buy_amount);
        }
        return; // Skip exhaustion logic this tick
    }
    
    // --- CORE EXHAUSTION STRATEGY ---
    
    // Condition 1: Price significantly above 60-period MA
    // "Significantly" defined as >1% above ma_60
    let price_above_ma = false;
    if (market.ma_60 > 0) {
        let threshold = market.ma_60 * 1 / 100; // 1% above
        price_above_ma = (market.price > (market.ma_60 + threshold));
    }
    
    // Condition 2: Volume exhaustion (current volume < 5% of 20-period avg)
    let volume_exhausted = false;
    let hist_len = market.history_len();
    if (hist_len >= 20) {
        let vol_sum = 0;
        let j = 0;
        while (j < 20) {
            vol_sum += market.history_volume(hist_len - 1 - j);
            j += 1;
        }
        let avg_volume_20 = vol_sum / 20;
        let exhaustion_threshold = avg_volume_20 * 5 / 100; // 5% of average
        volume_exhausted = (market.volume < exhaustion_threshold);
    }
    
    // If both conditions met, initiate short/sell position
    if (price_above_ma && volume_exhausted) {
        // STUBBORN HOLDER RULE: Only sell if price > avg_cost (no loss selling)
        if (account.stock > 0) {
            // We have inventory, only sell if profitable
            if (market.price > account.avg_cost) {
                // Sell all holdings
                orders.submit_market_sell(account.stock);
            } else {
                // Hold - diamond hands!
            }
        } else {
            // No inventory, can short via market sell
            // Conservative short size
            let short_size = base_position_size / 2;
            orders.submit_market_sell(short_size);
        }
    }
}