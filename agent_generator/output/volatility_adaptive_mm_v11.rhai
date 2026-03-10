let price_history = [];
let initialized = false;
let base_spread_bps = 10;
let max_spread_bps = 50;
let min_spread_bps = 5;
let order_size = 100;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        // Initialize with some randomness for order size
        order_size = rng.rand_int(80, 120);
    }
    
    // Update price history for FOMO check
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    // FOMO condition: price jumped >2% in last 5 ticks
    if price_history.len() == 5 {
        let old_price = price_history[0];
        let current_price = price_history[price_history.len() - 1];
        let price_change_pct = (current_price - old_price) * 10000 / old_price;
        
        if price_change_pct > 200 {
            // Market buy with 50% of available cash
            let max_buy = account.cash / market.price;
            let buy_amount = max_buy * 50 / 100;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }
    
    // Cancel all existing orders
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Calculate volatility-adjusted spread
    let mid_price = market.price;
    if mid_price == 0 { return; }
    
    // Normalize volatility (std_dev) to basis points
    let volatility_bps = (market.std_dev * 10000) / mid_price;
    let volatility_bps = clamp_val(volatility_bps, 0, 1000);
    
    // Spread = base + (volatility * 2) bps, clamped to min/max
    let spread_bps = base_spread_bps + (volatility_bps * 2);
    let spread_bps = clamp_val(spread_bps, min_spread_bps, max_spread_bps);
    
    // Calculate bid/ask prices
    let half_spread = (mid_price * spread_bps) / (10000 * 2);
    let bid_price = mid_price - half_spread;
    let ask_price = mid_price + half_spread;
    
    // Ensure minimum spread of 1 micro
    if ask_price <= bid_price {
        ask_price = bid_price + 1;
    }
    
    // Place market making orders
    if bid_price > 0 {
        orders.submit_limit_buy(bid_price, order_size);
    }
    if ask_price > 0 {
        orders.submit_limit_sell(ask_price, order_size);
    }
}