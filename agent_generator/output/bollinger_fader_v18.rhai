// Global variables persist across ticks
let initialized = false;
let base_order_amount = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        // Initialize with random base amount between 50-150 shares
        base_order_amount = rng.rand_int(50, 150);
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all existing orders
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Check if we have necessary indicators
    if market.ma_20 == 0 || market.std_dev == 0 { return; }
    
    // Calculate Bollinger Bands
    let lower_band = market.ma_20 - 2 * market.std_dev;
    let upper_band = market.ma_20 + 2 * market.std_dev;
    
    // Place limit buy at lower band + 1 micro (Off-by-One Pumper quirk)
    let buy_price = lower_band + 1;
    
    // Calculate buy amount (respect cash constraints)
    let max_buy_shares = account.cash / buy_price;
    let buy_amount = if base_order_amount < max_buy_shares { 
        base_order_amount 
    } else { 
        max_buy_shares 
    };
    
    if buy_amount > 0 && buy_price > 0 {
        orders.submit_limit_buy(buy_price, buy_amount);
    }
    
    // Place limit sell at upper band
    let sell_price = upper_band;
    
    // Calculate sell amount (respect inventory constraints)
    let sell_amount = if base_order_amount < account.stock { 
        base_order_amount 
    } else { 
        account.stock 
    };
    
    if sell_amount > 0 && sell_price > 0 {
        orders.submit_limit_sell(sell_price, sell_amount);
    }
}