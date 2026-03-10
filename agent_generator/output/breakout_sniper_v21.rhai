let initialized = false;
let BUY_AMOUNT = 1000;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Morning Person: Only active first 20% of session
    if market.tick * 5 >= market.total_ticks {
        // Cancel any remaining orders
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    // Cancel all pending orders each tick to avoid stale orders
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Breakout condition: price breaks above 20-tick high
    if market.price > market.high_20 && account.cash > 1000000 {
        // Aggressive buy at market
        orders.submit_market_buy(BUY_AMOUNT);
    }
    
    // Stubborn Holder: Only sell if price > avg_cost (no loss selling)
    // Set stop-loss 5 ticks below avg_cost, but only if it would be profitable
    if account.stock > 0 {
        let stop_price = account.avg_cost - 5;
        let current_best_bid = market.bid_price_0;
        
        // Only place sell if price would be above avg_cost (strictly greater)
        if current_best_bid > account.avg_cost {
            // Use limit sell at current bid to ensure execution
            orders.submit_limit_sell(current_best_bid, account.stock);
        }
    }
}