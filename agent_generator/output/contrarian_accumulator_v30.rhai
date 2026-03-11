let initialized = false;
let base_lot_size = 0;
let last_trade_profit = 0;
let last_trade_was_loss = false;

fn on_tick() {
    if !initialized {
        // Initialize base lot size: less than 5% of total capital
        let equity = account.total_equity;
        let price = market.price;
        if price > 0 {
            let max_shares = (equity * 5 / 100) / price;
            if max_shares > 0 {
                base_lot_size = rng.rand_int(20, clamp_val(max_shares, 20, 100));
            } else {
                base_lot_size = 20;
            }
        }
        last_trade_profit = 0;
        last_trade_was_loss = false;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Morning person: only active during first 20% of session
    if market.tick >= market.total_ticks * 20 / 100 {
        return;
    }
    
    // Risk-averse: refuse to trade if volatility is high (std_dev > 5% of price)
    let price = market.price;
    let volatility_threshold = price * 5 / 100;
    if market.std_dev > volatility_threshold {
        return;
    }
    
    // Cancel all pending orders first
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Check for recent fills to track profit/loss
    let fill_count = my_orders.fill_count();
    if fill_count > 0 {
        // Simple profit tracking: compare current price with average cost
        if account.avg_cost > 0 {
            let current_value = price - account.avg_cost;
            if account.stock > 0 {
                // We hold stock, check if current price is below avg cost
                last_trade_was_loss = current_value < 0;
            } else {
                // No stock, last trade was sell, check if price went up after selling
                last_trade_was_loss = current_value > 0;
            }
        }
    }
    
    // Determine lot size with martingale: double if last trade was loss
    let lot_size = base_lot_size;
    if last_trade_was_loss {
        lot_size = base_lot_size * 2;
    }
    
    // Clamp lot size to reasonable bounds
    lot_size = clamp_val(lot_size, 20, 100);
    
    // Contrarian RSI logic
    let rsi = market.rsi_14;
    
    if rsi < 3000 {
        // Oversold: buy with limit order below current price
        if lot_size > 0 && account.cash >= price * lot_size {
            let buy_price = price - (price * 1 / 100);  // 1% below current
            orders.submit_limit_buy(buy_price, lot_size);
        }
    } else if rsi > 7000 {
        // Overbought: sell with limit order above current price
        if lot_size > 0 && account.stock >= lot_size {
            let sell_price = price + (price * 1 / 100);  // 1% above current
            orders.submit_limit_sell(sell_price, lot_size);
        }
    }
}