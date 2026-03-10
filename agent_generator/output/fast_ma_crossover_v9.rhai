let initialized = false;
let last_ma5 = 0;
let last_ma20 = 0;
let buy_signal = false;
let sell_signal = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel any pending orders older than 3 ticks
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Check for MA crossover
    let current_ma5 = market.ma_5;
    let current_ma20 = market.ma_20;
    
    // Detect crossover up (bullish)
    if last_ma5 <= last_ma20 && current_ma5 > current_ma20 {
        buy_signal = true;
        sell_signal = false;
    }
    
    // Detect crossover down (bearish)
    if last_ma5 >= last_ma20 && current_ma5 < current_ma20 {
        sell_signal = true;
        buy_signal = false;
    }
    
    // Update last values for next tick
    last_ma5 = current_ma5;
    last_ma20 = current_ma20;
    
    // Execute buy signal
    if buy_signal && account.stock == 0 && my_orders.pending_count() == 0 {
        // Calculate amount based on available cash (use 95% of cash)
        let available_cash = account.cash;
        let buy_amount = available_cash * 95 / 100 / market.price;
        if buy_amount > 0 {
            orders.submit_limit_buy(market.price, buy_amount);
        }
    }
    
    // Execute sell signal
    if sell_signal && account.stock > 0 && my_orders.pending_count() == 0 {
        orders.submit_limit_sell(market.price, account.stock);
    }
    
    // Clear signals after execution attempt
    buy_signal = false;
    sell_signal = false;
}