// Generation Failed after 5 retries.
// Last error: FATAL: Function definitions must be at global level (no leading spaces). Do not nest `fn` inside blocks.
let entered = false;
let entry_price = 0;
let take_profit_placed = false;
let stop_loss_placed = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Cancel any existing orders
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Random entry once
    if !entered && rng.rand_bool(1) {
        // Buy 100 shares at market
        orders.submit_market_buy(100);
        entered = true;
    }
    
    if entered && account.stock > 0 {
        // Calculate current cost basis
        let cost = account.avg_cost;
        
        // Round to nearest dollar function
        fn round_to_dollar(price) {
            ((price + 500_000) / 1_000_000) * 1_000_000
        }
        
        // Only place sell orders if price > cost (Diamond Hands)
        if market.price > cost {
            // Take profit at 5% above cost (rounded)
            let take_profit_price = round_to_dollar(cost * 105 / 100);
            
            // Place take profit limit order
            if !take_profit_placed {
                orders.submit_limit_sell(take_profit_price, account.stock);
                take_profit_placed = true;
            }
            
            // Stop loss at 2% below cost (market order when triggered)
            let stop_loss_trigger = cost * 98 / 100;
            
            // Check if price dropped to stop loss level
            if market.price <= stop_loss_trigger && !stop_loss_placed {
                orders.submit_market_sell(account.stock);
                stop_loss_placed = true;
            }
        }
    }
}