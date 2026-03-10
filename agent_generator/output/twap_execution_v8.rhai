// Global variables persist across ticks
let initialized = false;
let target_position = 50_000;  // shares to accumulate
let remaining_to_buy = 50_000;
let slice_size = 500;  // shares per slice
let ticks_between_orders = 10;
let tick_counter = 0;
let last_order_tick = -100;
let price_history = [];
let lot_size = 0;
let fomo_triggered = false;
let std_dev_threshold = 0;

fn on_tick() {
    // Initialization
    if !initialized {
        initialized = true;
        
        // Risk-averse: Initialize lot size < 5% of total capital
        let max_capital_for_trade = account.total_equity * 5 / 100;
        let max_shares = max_capital_for_trade / market.price;
        if max_shares < 1 { max_shares = 1; }
        
        // Random slice size up to max_shares
        slice_size = rng.rand_int(1, max_shares);
        if slice_size > 500 { slice_size = 500; }
        
        // Randomize interval between 5-15 ticks
        ticks_between_orders = rng.rand_int(5, 15);
        
        // Set std dev threshold (2% of current price)
        std_dev_threshold = market.price * 2 / 100;
    }
    
    if !market.trading_enabled { return; }
    
    // Update price history for FOMO detection (last 5 ticks)
    if price_history.len() >= 5 {
        price_history.remove(0);
    }
    price_history.push(market.price);
    
    // FOMO: Check for >2% jump in last 5 ticks
    if !fomo_triggered && price_history.len() >= 2 {
        let oldest_idx = 0;
        let newest_idx = price_history.len() - 1;
        let old_price = price_history[oldest_idx];
        let new_price = price_history[newest_idx];
        let price_change = abs_val(new_price - old_price);
        let change_percent = price_change * 10000 / old_price;
        
        if change_percent > 200 {  // >2%
            fomo_triggered = true;
            // Market buy immediately
            let buy_amount = remaining_to_buy;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
                remaining_to_buy = 0;
                return;
            }
        }
    }
    
    // Risk-averse: Don't trade if volatility is high
    if market.std_dev > std_dev_threshold {
        return;
    }
    
    // Cancel all pending orders at each step
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Update tick counter
    tick_counter += 1;
    
    // Check if it's time for next slice
    if fomo_triggered { return; }
    if remaining_to_buy <= 0 { return; }
    
    if tick_counter - last_order_tick >= ticks_between_orders {
        // Calculate order amount
        let order_amount = slice_size;
        if order_amount > remaining_to_buy {
            order_amount = remaining_to_buy;
        }
        
        // Round number bias: Calculate rounded price (nearest 1,000,000)
        let raw_price = market.price;
        let remainder = raw_price % 1_000_000;
        let rounded_price = raw_price - remainder;
        if remainder >= 500_000 {
            rounded_price += 1_000_000;
        }
        
        // Submit limit buy at rounded price
        orders.submit_limit_buy(rounded_price, order_amount);
        
        // Update tracking variables
        last_order_tick = tick_counter;
        remaining_to_buy -= order_amount;
    }
}