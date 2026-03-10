let initialized = false;
let price_history = [];
let high_20_history = [];
let breakout_triggered = false;
let stop_loss_offset = 0;
let entry_tick = 0;
let position_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_offset = micros(0, 10);
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
    
    // Store current market data for delayed reaction
    price_history.push(market.price);
    high_20_history.push(market.high_20);
    
    // Keep only last 5 ticks
    if price_history.len() > 5 {
        price_history.remove(0);
        high_20_history.remove(0);
    }
    
    // Only react when we have 5 ticks of history
    if price_history.len() < 5 {
        return;
    }
    
    // Use data from 5 ticks ago
    let delayed_price = price_history[0];
    let delayed_high_20 = high_20_history[0];
    
    // Reset breakout flag if no position
    if account.stock == 0 {
        breakout_triggered = false;
        position_size = 0;
        entry_tick = 0;
    }
    
    // Breakout buy condition (delayed)
    if !breakout_triggered && account.stock == 0 && delayed_price > delayed_high_20 {
        breakout_triggered = true;
        
        // Aggressive buy - use 50% of cash
        let available_cash = account.cash * 50 / 100;
        let buy_amount = available_cash / market.price;
        
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
            position_size = buy_amount;
            entry_tick = market.tick;
        }
    }
    
    // Stubborn holder: only sell if price > avg_cost (delayed)
    if account.stock > 0 && account.avg_cost > 0 && delayed_price > account.avg_cost {
        // Check if we should place stop-loss
        let stop_price = account.avg_cost - stop_loss_offset;
        
        if delayed_price <= stop_price {
            // Sell entire position at market
            orders.submit_market_sell(account.stock);
        }
    }
}