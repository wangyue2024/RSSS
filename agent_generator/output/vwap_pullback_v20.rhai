// Global variables persist across ticks
let price_history = [];
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        // Initialize with current price
        if market.trading_enabled {
            price_history.push(market.price);
        }
        return;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders each tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Store current price in history
    price_history.push(market.price);
    
    // Keep only last 5 ticks
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    // Only act if we have 5 ticks of history
    if price_history.len() == 5 {
        // Use price from 5 ticks ago (delayed reaction)
        let delayed_price = price_history[0];
        let current_vwap = market.vwap;
        
        // Calculate threshold: 2% below VWAP
        let threshold = current_vwap * 2 / 100;
        let buy_condition_price = current_vwap - threshold;
        
        // Check if delayed price is significantly below VWAP
        if delayed_price < buy_condition_price {
            // Buy condition met - use 10% of available cash
            let cash_to_use = account.cash * 10 / 100;
            let buy_amount = cash_to_use / market.price;
            
            if buy_amount > 0 && market.price > 0 {
                orders.submit_limit_buy(market.price, buy_amount);
            }
        }
        
        // Sell condition: only if current price > average cost AND above VWAP
        let sell_condition_price = current_vwap;
        
        if market.price > sell_condition_price && 
           market.price > account.avg_cost && 
           account.stock > 0 {
            // Sell all stock
            orders.submit_limit_sell(market.price, account.stock);
        }
    }
}