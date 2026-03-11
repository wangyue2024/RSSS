let initialized = false;
let base_order_size = 100;
let fomo_triggered = false;
let last_prices = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        base_order_size = rng.rand_int(80, 120);
    }
    
    if !market.trading_enabled { return; }
    
    // Morning person: only trade first 20% of session
    if market.tick >= market.total_ticks / 5 {
        return;
    }
    
    // Track recent prices for FOMO detection (last 3 ticks)
    last_prices.push(market.price);
    if last_prices.len() > 3 {
        last_prices.remove(0);
    }
    
    // FOMO check: price jumped >2% in last 2 ticks
    if last_prices.len() >= 2 && !fomo_triggered {
        let old_price = last_prices[0];
        let jump_pct = (market.price - old_price) * 10000 / old_price;
        if jump_pct > 200 {
            fomo_triggered = true;
            // Market buy with available cash
            let max_shares = account.cash / market.price;
            let buy_amount = clamp_val(max_shares / 2, 1, 1000);
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }
    
    // Cancel all pending orders
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Calculate range spread
    let spread = market.high_20 - market.low_20;
    if spread <= 0 { return; }
    
    // Adjust position size based on spread (inverse relationship)
    let spread_ratio = 5000000 / (spread + 10000); // 5 yuan / spread
    let order_size = base_order_size * spread_ratio / 1000;
    let size = clamp_val(order_size, 10, 500);
    
    // Place limit buy near low_20 (slightly above)
    let buy_price = market.low_20 + spread * 10 / 100;
    if buy_price < market.price && account.cash >= buy_price * size {
        orders.submit_limit_buy(buy_price, size);
    }
    
    // Place limit sell near high_20 (slightly below)
    let sell_price = market.high_20 - spread * 10 / 100;
    if sell_price > market.price && account.stock >= size {
        orders.submit_limit_sell(sell_price, size);
    }
}