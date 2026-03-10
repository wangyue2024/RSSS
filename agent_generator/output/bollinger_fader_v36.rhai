let initialized = false;
let price_history = [];
let last_tick_processed = -50;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        // Initialize price history with current price
        for i in 0..5 {
            price_history.push(market.price);
        }
    }
    
    // Update price history (rolling window of 5 ticks)
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    // FOMO check - runs every tick regardless of lazy trader
    if price_history.len() == 5 {
        let old_price = price_history[0];
        let price_change = abs_val(market.price - old_price);
        // Check if price moved more than 2% (2% = 20_000 / 1_000_000)
        if old_price != 0 && (price_change * 100 / old_price) > 2 {
            // Market buy immediately
            let buy_amount = clamp_val(account.cash / market.price, 1, 1000);
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            // Cancel all pending orders since we're abandoning strategy
            let pending_count = my_orders.pending_count();
            let i = 0;
            while i < pending_count {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
            return;
        }
    }
    
    // Lazy trader - only run main strategy every 50 ticks
    if (market.tick - last_tick_processed) < 50 {
        return;
    }
    
    last_tick_processed = market.tick;
    
    // Cancel all existing orders
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Calculate Bollinger Bands
    let ma_20 = market.ma_20;
    let std_dev = market.std_dev;
    
    if ma_20 != 0 && std_dev != 0 {
        let lower_band = ma_20 - 2 * std_dev;
        let upper_band = ma_20 + 2 * std_dev;
        
        // Place limit buy at lower band + 1 micro (Off-by-One Pumper)
        let buy_price = lower_band + 1;
        let buy_amount = clamp_val(account.cash / buy_price, 1, 1000);
        if buy_amount > 0 && buy_price > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
        
        // Place limit sell at upper band
        if account.stock > 0 {
            let sell_amount = clamp_val(account.stock, 1, 1000);
            orders.submit_limit_sell(upper_band, sell_amount);
        }
    }
}