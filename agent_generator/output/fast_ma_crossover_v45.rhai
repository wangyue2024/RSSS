// Global state
let ma_crossover_initialized = false;
let prev_ma5_above_ma20 = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Morning person: only trade in first 20% of session
    if market.tick >= market.total_ticks * 1 / 5 {
        // Exit any position if we're past the active period
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        
        // Cancel any pending orders
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    // Initialize on first tick
    if !ma_crossover_initialized {
        ma_crossover_initialized = true;
        prev_ma5_above_ma20 = market.ma_5 > market.ma_20;
        return;
    }
    
    // Cancel any pending orders
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Check crossover
    let current_ma5_above_ma20 = market.ma_5 > market.ma_20;
    
    // Buy signal: MA_5 crosses above MA_20
    if current_ma5_above_ma20 && !prev_ma5_above_ma20 {
        // Calculate how much we can buy with available cash
        if market.ask_price_0 > 0 && account.cash > 0 {
            // Use best ask price for estimation
            let max_shares = account.cash / market.ask_price_0;
            if max_shares > 0 {
                orders.submit_market_buy(max_shares);
            }
        }
    }
    
    // Sell signal: MA_5 crosses below MA_20
    if !current_ma5_above_ma20 && prev_ma5_above_ma20 {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
    }
    
    // Update previous state
    prev_ma5_above_ma20 = current_ma5_above_ma20;
}