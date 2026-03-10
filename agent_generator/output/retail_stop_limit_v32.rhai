let attempted_entry = false;
let entered_position = false;
let entry_price = 0;
let position_size = 0;
let take_profit_order_id = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Cancel any pending orders if we have no position (cleanup)
    if !entered_position {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
    }
    
    // Risk check: refuse to trade if volatility (std_dev) is high (>2% of price)
    let two_percent_price = market.price * 2 / 100;
    if market.std_dev > two_percent_price {
        return;
    }
    
    // Entry logic: try once randomly
    if !attempted_entry && !entered_position {
        attempted_entry = true;
        
        // Determine max lot size (<5% of total capital)
        let max_trade_capital = account.total_equity * 5 / 100;
        if max_trade_capital <= 0 { return; }
        
        // Calculate max shares affordable at current price
        let max_shares = max_trade_capital / market.price;
        if max_shares <= 0 { return; }
        
        // Randomly determine lot size (1 to max_shares)
        position_size = rng.rand_int(1, max_shares);
        
        // Place market buy
        orders.submit_market_buy(position_size);
        
        // Set entry price (approximate - market order fills immediately)
        entry_price = market.price;
        entered_position = true;
        
        // Place take-profit limit order (5% above entry)
        let take_profit_price = entry_price * 105 / 100;
        take_profit_order_id = orders.submit_limit_sell(take_profit_price, position_size);
        
        // Note: Stop-loss is a MARKET order, so we'll trigger it conditionally
    }
    
    // Position management
    if entered_position {
        // Check if take-profit order still exists
        let tp_active = false;
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            if my_orders.pending_id(i) == take_profit_order_id {
                tp_active = true;
                break;
            }
            i += 1;
        }
        
        // If take-profit order is gone (filled), reset
        if !tp_active {
            entered_position = false;
            entry_price = 0;
            position_size = 0;
            take_profit_order_id = 0;
            return;
        }
        
        // Check stop-loss condition (2% below entry)
        let stop_loss_price = entry_price * 98 / 100;
        if market.price <= stop_loss_price {
            // Cancel take-profit order
            orders.submit_cancel(take_profit_order_id);
            
            // Execute stop-loss market sell
            orders.submit_market_sell(position_size);
            
            // Reset state
            entered_position = false;
            entry_price = 0;
            position_size = 0;
            take_profit_order_id = 0;
        }
    }
}