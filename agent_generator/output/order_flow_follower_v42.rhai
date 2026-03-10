let initialized = false;
let lot_size = 0;
let std_dev_threshold = 0;
let max_positions = 0;

fn on_tick() {
    if !initialized {
        // Initialize risk parameters
        let five_percent_cap = account.total_equity * 500 / 10000;
        let max_shares = five_percent_cap / market.price;
        if max_shares < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
        
        std_dev_threshold = market.price * 300 / 10000; // 3% of price
        max_positions = rng.rand_int(1, 5);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Check volatility - too high, don't trade
    if market.std_dev > std_dev_threshold {
        return;
    }
    
    // Check current position size - too high, don't trade
    let current_positions = my_orders.pending_count() + account.stock;
    if current_positions >= max_positions {
        return;
    }
    
    // Main order flow logic
    if market.buy_volume > 3 * market.sell_volume && market.buy_volume > 0 {
        orders.submit_market_buy(lot_size);
    }
}