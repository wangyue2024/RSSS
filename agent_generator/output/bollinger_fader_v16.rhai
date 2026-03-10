let initialized = false;
let lot_size = 0;
let risk_multiplier = 0;
let max_cash_usage = 500000;  // 50% as 50 * 10000

fn on_tick() {
    if !initialized {
        risk_multiplier = rng.rand_int(1, 5);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    if market.ma_20 == 0 { return; }
    if market.std_dev == 0 { return; }
    
    // Cancel all existing orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Calculate Bollinger Bands
    let upper_band = market.ma_20 + 2 * market.std_dev;
    let lower_band = market.ma_20 - 2 * market.std_dev;
    
    // Determine lot size based on available cash
    let cash_available = account.cash;
    if cash_available > 0 {
        // Risk-seeking: use random percentage of cash (25-50%)
        let use_pct = rng.rand_int(2500, 5000);  // 25-50% in basis points
        let cash_to_use = cash_available * use_pct / 10000;
        
        // Convert to shares at current price
        if market.price > 0 {
            let shares = cash_to_use / market.price;
            if shares > 0 {
                lot_size = shares * risk_multiplier;
            }
        }
    }
    
    // Place limit orders
    if lot_size > 0 {
        if market.price > lower_band && lower_band > 0 {
            orders.submit_limit_buy(lower_band, lot_size);
        }
        if market.price < upper_band {
            orders.submit_limit_sell(upper_band, lot_size);
        }
    }
}