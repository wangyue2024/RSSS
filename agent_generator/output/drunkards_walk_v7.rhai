// Global state for drunkards_walk strategy
let initialized = false;
let max_lot_size = 0;
let price_history = [];
let fomo_trigger_percent = 20000; // 2% in basis points (10000 = 1%)

fn on_tick() {
    if !initialized {
        initialized = true;
        
        // Risk-averse: Initialize max lot size to less than 5% of total capital
        let five_percent_capital = account.total_equity * 5 / 100;
        let max_shares = five_percent_capital / market.price;
        if max_shares < 1 {
            max_shares = 1;
        }
        max_lot_size = rng.rand_int(1, max_shares);
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders at start of each tick
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Update price history for FOMO detection
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    // Risk-averse: Don't trade if volatility is too high
    // Consider std_dev > 3% of price as high
    let volatility_threshold = market.price * 3 / 100;
    if market.std_dev > volatility_threshold {
        return;
    }
    
    // FOMO check: If price jumped >2% in last 5 ticks
    if price_history.len() >= 5 {
        let old_price = price_history[0];
        let price_change = abs_val(market.price - old_price) * 10000 / old_price;
        
        if price_change > fomo_trigger_percent && market.price > old_price {
            // Market buy with random size (but limited)
            let buy_amount = rng.rand_int(1, max_lot_size);
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return; // Skip random trading when FOMO triggered
        }
    }
    
    // Core random trading strategy
    let random_val = rng.rand_int(0, 99);
    
    if random_val < 5 {
        // Random buy
        let price_offset_bps = rng.rand_int(-100, 100); // -1% to +1% in basis points
        let limit_price = market.price + (market.price * price_offset_bps / 10000);
        let buy_amount = rng.rand_int(1, max_lot_size);
        
        if limit_price > 0 && buy_amount > 0 {
            orders.submit_limit_buy(limit_price, buy_amount);
        }
    } else if random_val > 95 {
        // Random sell (only if we have stock)
        if account.stock > 0 {
            let price_offset_bps = rng.rand_int(-100, 100); // -1% to +1% in basis points
            let limit_price = market.price + (market.price * price_offset_bps / 10000);
            let sell_amount = rng.rand_int(1, account.stock);
            
            if limit_price > 0 && sell_amount > 0 {
                orders.submit_limit_sell(limit_price, sell_amount);
            }
        }
    }
}