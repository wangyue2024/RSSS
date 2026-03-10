// Global variables persist across ticks
let initialized = false;
let lot_size = 0;
let cluster_threshold = 0;
let std_dev_threshold = 0;

fn round_to_dollar(price) {
    let remainder = price % 1_000_000;
    let base = price - remainder;
    if remainder >= 500_000 {
        base + 1_000_000
    } else {
        base
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        // Initialize lot_size to less than 5% of total capital
        let max_lot = account.total_equity * 5 / 100;
        if max_lot > 0 {
            lot_size = rng.rand_int(1, max_lot);
        } else {
            lot_size = 1;
        }
        
        // Initialize thresholds
        cluster_threshold = lot_size * 3;
        std_dev_threshold = market.price * 2 / 100; // 2% threshold
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Risk-averse: refuse to trade if std_dev is high
    if market.std_dev > std_dev_threshold {
        return;
    }
    
    // Check for cluster of orders below current price (bid side)
    let total_bid_volume = 0;
    total_bid_volume += market.bid_vol_0;
    total_bid_volume += market.bid_vol_1;
    total_bid_volume += market.bid_vol_2;
    total_bid_volume += market.bid_vol_3;
    total_bid_volume += market.bid_vol_4;
    
    // Check if there's a significant cluster of bids
    if total_bid_volume > cluster_threshold && account.stock >= lot_size {
        // Aggressive market sell to push price down
        orders.submit_market_sell(lot_size);
        
        // Calculate buy price 1% below current price, rounded to dollar
        let target_buy_price = market.price * 99 / 100;
        let rounded_buy_price = round_to_dollar(target_buy_price);
        
        // Place limit buy at rounded price
        orders.submit_limit_buy(rounded_buy_price, lot_size);
    }
}