// Global variables
let price_buffer = [];
let last_rebalance_tick = -10;
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        // Initialization if needed
    }
    
    if !market.trading_enabled { return; }
    
    // Store current price in buffer (delayed reaction)
    price_buffer.push(market.price);
    
    // Keep only last 5 ticks
    while price_buffer.len() > 5 {
        price_buffer.remove(0);
    }
    
    // Only proceed if we have 5-ticks-old data
    if price_buffer.len() < 5 { return; }
    
    let delayed_price = price_buffer[0];
    let current_tick = market.tick;
    
    // Cancel all existing orders at rebalance time
    if current_tick - last_rebalance_tick >= 10 {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        // Calculate current allocation using delayed price
        let stock_value = account.stock * delayed_price;
        let equity = account.cash + stock_value;
        
        // Avoid division by zero
        if equity == 0 { return; }
        
        // Calculate stock percentage (in basis points: 1% = 100)
        let stock_pct = stock_value * 10000 / equity;
        
        // Target range: 45% to 55%
        if stock_pct > 5500 || stock_pct < 4500 {
            // Calculate target stock value (50% of equity)
            let target_stock_value = equity / 2;
            
            // Calculate difference in shares needed
            let shares_diff = (target_stock_value - stock_value) / delayed_price;
            
            // Round to nearest integer share (avoid fractional shares)
            let shares_to_trade = if shares_diff > 0 {
                (shares_diff + 500_000) / 1_000_000  // Round up for buy
            } else {
                (shares_diff - 500_000) / 1_000_000  // Round down for sell
            };
            
            // Clamp to reasonable size (max 100 shares)
            let trade_size = clamp_val(abs_val(shares_to_trade), 1, 100);
            
            // Round number bias: round to nearest whole dollar
            let raw_price = delayed_price / 1_000_000;  // Convert to dollars
            let rounded_dollars = if raw_price % 1_000_000 >= 500_000 {
                raw_price + 1_000_000
            } else {
                raw_price
            } / 1_000_000 * 1_000_000;
            
            let limit_price = rounded_dollars * 1_000_000;
            
            // Place limit order
            if shares_to_trade > 0 {
                orders.submit_limit_buy(limit_price, trade_size);
            } else if shares_to_trade < 0 {
                orders.submit_limit_sell(limit_price, trade_size);
            }
            
            last_rebalance_tick = current_tick;
        }
    }
}