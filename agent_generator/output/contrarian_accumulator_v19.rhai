let initialized = false;
let price_history = [];
let target_position = 0;
let order_size = 50;
let rsi_oversold = 3000;
let rsi_overbought = 7000;
let fomo_threshold_pct = 2;

fn on_tick() {
    if !initialized {
        initialized = true;
        order_size = rng.rand_int(20, 100);
    }
    
    if !market.trading_enabled { return; }
    
    // Morning person check
    if market.tick >= market.total_ticks / 5 {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    // Cancel existing orders
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Update price history for FOMO check
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    // FOMO check: price jumped >2% in last 5 ticks
    if price_history.len() >= 2 {
        let oldest_price = price_history[0];
        let jump_threshold = oldest_price * fomo_threshold_pct / 100;
        if (market.price - oldest_price) > jump_threshold {
            let buy_amount = order_size;
            if account.cash > buy_amount * market.price {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }
    
    // Contrarian RSI logic
    if market.rsi_14 < rsi_oversold && account.cash > order_size * market.price {
        let limit_price = market.price * 995 / 1000;
        target_position += order_size;
        orders.submit_limit_buy(limit_price, order_size);
    } else if market.rsi_14 > rsi_overbought && account.stock > 0 {
        let sell_amount = if account.stock < order_size { account.stock } else { order_size };
        let limit_price = market.price * 1005 / 1000;
        target_position -= sell_amount;
        orders.submit_limit_sell(limit_price, sell_amount);
    }
}