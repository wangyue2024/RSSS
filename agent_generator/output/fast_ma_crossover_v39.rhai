let initialized = false;
let lot_size = 0;
let prev_ma5 = 0;
let prev_ma20 = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        // Initialize risk-averse lot size: less than 5% of total capital
        let max_capital_use = account.total_equity * 5 / 100;
        let max_shares = max_capital_use / market.price;
        if max_shares > 0 {
            lot_size = rng.rand_int(1, max_shares);
        } else {
            lot_size = 1;
        }
        prev_ma5 = market.ma_5;
        prev_ma20 = market.ma_20;
    }
    
    if !market.trading_enabled { return; }
    
    // Lazy trader: only act every 50 ticks
    if market.tick % 50 != 0 { return; }
    
    // Risk-averse: refuse to trade if volatility is high (std_dev > 5% of price)
    if market.std_dev > market.price * 5 / 100 { return; }
    
    // Cancel all pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    let current_ma5 = market.ma_5;
    let current_ma20 = market.ma_20;
    
    // Check for MA5 crossing above MA20
    let ma5_crossed_up = prev_ma5 <= prev_ma20 && current_ma5 > current_ma20;
    // Check for MA5 crossing below MA20
    let ma5_crossed_down = prev_ma5 >= prev_ma20 && current_ma5 < current_ma20;
    
    if ma5_crossed_up {
        // Buy at market price
        if lot_size > 0 {
            orders.submit_market_buy(lot_size);
        }
    } else if ma5_crossed_down {
        // Sell all inventory
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
    }
    
    // Update previous values for next comparison
    prev_ma5 = current_ma5;
    prev_ma20 = current_ma20;
}