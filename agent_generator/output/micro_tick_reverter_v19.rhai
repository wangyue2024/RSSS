let initialized = false;
let panic_threshold = 0;
let last_price = 0;
let recent_prices = [];

fn on_tick() {
    if !initialized {
        panic_threshold = -rng.rand_int(100_000, 1_000_000);
        last_price = market.price;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders each tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Panic condition: sell everything if unrealized loss exceeds threshold
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    // Update price history for FOMO window (5 ticks)
    if recent_prices.len() >= 5 {
        recent_prices.remove(0);
    }
    recent_prices.push(market.price);
    
    // FOMO condition: price jump >2% in last 5 ticks
    if recent_prices.len() >= 2 {
        let min_price = recent_prices[0];
        let i = 1;
        while i < recent_prices.len() {
            if recent_prices[i] < min_price {
                min_price = recent_prices[i];
            }
            i += 1;
        }
        
        if market.price > min_price && (market.price - min_price) * 100 > min_price * 2 {
            let buy_shares = account.cash / market.price;
            if buy_shares > 0 {
                orders.submit_market_buy(buy_shares);
            }
            last_price = market.price;
            return;
        }
    }
    
    // Core mean reversion logic
    if market.price < last_price {
        let buy_price = market.price * 999 / 1000;
        let buy_amount = 10;
        orders.submit_limit_buy(buy_price, buy_amount);
    } else if market.price > last_price && account.stock > 0 {
        let sell_price = market.price * 1001 / 1000;
        let sell_amount = if account.stock < 10 { account.stock } else { 10 };
        orders.submit_limit_sell(sell_price, sell_amount);
    }
    
    last_price = market.price;
}