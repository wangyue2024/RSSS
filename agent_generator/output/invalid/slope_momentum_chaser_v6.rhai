// Global state variables
let initialized = false;
let last_fomo_tick = -1000;
let panic_mode = false;
let panic_sell_threshold = -5000;
let momentum_threshold = 3000;
let acceleration_threshold = 1000;
let fomo_threshold = 20000; // 2% in micro units

fn compute_slope(arr) {
    if arr.len() < 2 {
        return 0;
    }
    return arr_slope(arr);
}

fn on_tick() {
    if !initialized {
        initialized = true;
        // Initialize with some randomness for thresholds
        momentum_threshold = rng.rand_int(2000, 4000);
        acceleration_threshold = rng.rand_int(800, 1200);
        panic_sell_threshold = rng.rand_int(-6000, -4000);
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders first
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Get recent price history for slope calculations
    let history_len = market.history_len();
    let recent_prices = [];
    
    // Collect last 20 prices if available
    let lookback = if history_len < 20 { history_len } else { 20 };
    let j = 0;
    while j < lookback {
        recent_prices.push(market.history_price(j));
        j += 1;
    }
    
    // FOMO check - price jumped 2%+ in 5 ticks
    if history_len >= 5 && market.tick - last_fomo_tick > 10 {
        let current_price = market.price;
        let price_5_ticks_ago = market.history_price(4);
        if price_5_ticks_ago > 0 {
            let price_change = (current_price * 10000) / price_5_ticks_ago - 10000;
            if price_change >= fomo_threshold {
                // FOMO triggered - market buy immediately
                let buy_amount = (account.cash * 30) / (100 * market.price);
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                }
                last_fomo_tick = market.tick;
                return;
            }
        }
    }
    
    if recent_prices.len() < 10 {
        return; // Not enough data
    }
    
    // Compute short-term slope (last 5 periods)
    let short_term = [];
    let k = 0;
    while k < 5 && k < recent_prices.len() {
        short_term.push(recent_prices[k]);
        k += 1;
    }
    let short_slope = compute_slope(short_term);
    
    // Compute medium-term slope (last 10 periods)
    let medium_term = [];
    let m = 0;
    while m < 10 && m < recent_prices.len() {
        medium_term.push(recent_prices[m]);
        m += 1;
    }
    let medium_slope = compute_slope(medium_term);
    
    // Check for panic sell condition
    if short_slope < panic_sell_threshold && medium_slope < 0 {
        panic_mode = true;
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    } else {
        panic_mode = false;
    }
    
    // Check for strong momentum with acceleration
    if medium_slope > momentum_threshold && short_slope > medium_slope + acceleration_threshold {
        // Calculate aggressive buy size
        let base_size = (account.cash * 15) / (100 * market.price);
        let boost = (short_slope * base_size) / 10000;
        let buy_amount = base_size + boost;
        
        if buy_amount > 0 && market.bid_price_0 > 0 {
            // Off-by-One Pumper: add exactly 1 micro to jump ahead
            let bid_price = market.bid_price_0 + 1;
            orders.submit_limit_buy(bid_price, buy_amount);
        }
    }
}