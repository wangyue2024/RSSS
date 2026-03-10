// Global variables
let initialized = false;
let last_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_price = market.price;
        return;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    
    // Check if price dropped (buy signal)
    if current_price < last_price {
        // Calculate base bid price (slightly below current) then add 1 micro
        let base_bid = current_price - 10;
        let bid_price = base_bid + 1;  // Off-by-One Pumper quirk
        let amount = 1000;
        
        // Place limit buy order
        orders.submit_limit_buy(bid_price, amount);
    }
    // Check if price rose (sell signal)
    else if current_price > last_price {
        // Calculate base ask price (slightly above current) then add 1 micro
        let base_ask = current_price + 10;
        let ask_price = base_ask + 1;  // Off-by-One Pumper quirk
        let amount = 1000;
        
        // Place limit sell order
        orders.submit_limit_sell(ask_price, amount);
    }
    
    // Update last_price for next tick
    last_price = current_price;
}