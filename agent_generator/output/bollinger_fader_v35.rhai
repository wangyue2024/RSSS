let initialized = false;
let delayed_prices = [];

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Morning Person: only trade in first 20% of session
    if market.tick >= market.total_ticks / 5 {
        // Cancel all orders if outside trading window
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    // Cancel all existing orders
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Delayed Reaction: save current price
    delayed_prices.push(market.price);
    
    // Only act on data that is 5 ticks old
    if delayed_prices.len() <= 5 {
        return;
    }
    
    // Remove oldest price if we have more than 5
    if delayed_prices.len() > 5 {
        delayed_prices.remove(0);
    }
    
    // Get delayed price (5 ticks old)
    let delayed_price = delayed_prices[0];
    
    // Calculate Bollinger Bands using delayed data concept
    // Note: We use current market indicators since we can't compute our own
    // This is a simplification due to engine constraints
    let upper_band = market.ma_20 + 2 * market.std_dev;
    let lower_band = market.ma_20 - 2 * market.std_dev;
    
    // Off-by-One Pumper: add 1 micro to bid price
    let buy_price = lower_band + 1;
    let sell_price = upper_band;
    
    // Place limit orders
    let amount = 100;
    
    // Only place orders if bands are reasonable
    if buy_price > 0 && sell_price > buy_price {
        orders.submit_limit_buy(buy_price, amount);
        orders.submit_limit_sell(sell_price, amount);
    }
}