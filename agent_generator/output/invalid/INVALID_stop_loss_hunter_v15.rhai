// Generation Failed after 5 retries.
// Last error: Violated NO FLOATS rule. Found floating point numbers like 0.5 or 12.34.
// Global variables persist across ticks
let initialized = false;
let panic_threshold = 0; // negative pnl threshold in micros
let cluster_threshold = 0; // volume threshold for stop loss detection
let min_profit_margin = 0; // minimum profit margin in micros

// Round to nearest integer dollar (1,000,000 micros)
fn round_price(price) {
    if price % 1_000_000 >= 500_000 {
        return ((price / 1_000_000) + 1) * 1_000_000;
    } else {
        return (price / 1_000_000) * 1_000_000;
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        // Initialize parameters with RNG
        panic_threshold = -rng.rand_int(10_000_000, 50_000_000); // -10 to -50 dollars
        cluster_threshold = rng.rand_int(5000, 20000); // volume threshold
        min_profit_margin = rng.rand_int(50_000, 200_000); // 0.05 to 0.20 dollars
    }
    
    if !market.trading_enabled { 
        return; 
    }
    
    // Panic check: if unrealized PnL is worse than threshold, market sell everything
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    // Cancel all pending orders at start of tick
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    let avg_cost = account.avg_cost;
    
    // Strategy 1: Look for stop loss clusters below current price
    // Check bid side for potential support levels
    let total_bid_volume = 0;
    let bid_levels = 0;
    
    // Check top 5 bid levels
    if market.bid_price_0 > 0 && market.bid_price_0 < current_price {
        total_bid_volume += market.bid_vol_0;
        bid_levels += 1;
    }
    if market.bid_price_1 > 0 && market.bid_price_1 < current_price {
        total_bid_volume += market.bid_vol_1;
        bid_levels += 1;
    }
    if market.bid_price_2 > 0 && market.bid_price_2 < current_price {
        total_bid_volume += market.bid_vol_2;
        bid_levels += 1;
    }
    if market.bid_price_3 > 0 && market.bid_price_3 < current_price {
        total_bid_volume += market.bid_vol_3;
        bid_levels += 1;
    }
    if market.bid_price_4 > 0 && market.bid_price_4 < current_price {
        total_bid_volume += market.bid_vol_4;
        bid_levels += 1;
    }
    
    // If we detect a cluster of bids below current price (potential stop losses)
    if bid_levels >= 3 && total_bid_volume > cluster_threshold && account.stock > 0) {
        // Check if we can sell at profit (Stubborn Holder rule)
        if current_price > avg_cost + min_profit_margin {
            // Aggressively market sell to push through support
            let sell_amount = account.stock;
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
                
                // Place limit buy order at depressed price (rounded)
                let depressed_price = round_price(current_price * 98 / 100); // 2% below
                let buy_amount = sell_amount;
                orders.submit_limit_buy(depressed_price, buy_amount);
            }
            return;
        }
    }
    
    // Strategy 2: Place profit-taking sell orders (only if price > avg_cost)
    if current_price > avg_cost + min_profit_margin && account.stock > 0 {
        // Calculate target sell price with profit margin
        let target_price = current_price * 102 / 100; // 2% above current
        target_price = round_price(target_price);
        
        // Only place sell order if it's above avg_cost (Stubborn Holder rule)
        if target_price > avg_cost + min_profit_margin {
            let sell_amount = account.stock;
            orders.submit_limit_sell(target_price, sell_amount);
        }
    }
    
    // Strategy 3: Place opportunistic buy orders
    if account.cash > 1_000_000 { // At least 1 dollar
        // Calculate buy price - look for dips
        let buy_price = round_price(current_price * 99 / 100); // 1% below
        let max_buy_amount = account.cash / buy_price;
        
        if max_buy_amount > 0 {
            // Randomize buy amount between 25% and 75% of max
            let buy_amount = max_buy_amount * rng.rand_int(25, 75) / 100;
            if buy_amount > 0 {
                orders.submit_limit_buy(buy_price, buy_amount);
            }
        }
    }
}