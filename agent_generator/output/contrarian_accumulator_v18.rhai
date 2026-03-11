let initialized = false;
let last_prices = [];
let fomo_triggered = false;
let buy_size = 0;
let sell_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        buy_size = rng.rand_int(20, 100);
        sell_size = rng.rand_int(20, 100);
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders at start of tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Update price window for FOMO detection
    last_prices.push(market.price);
    if last_prices.len() > 10 {
        last_prices.remove(0);
    }
    
    // FOMO condition: price jumped >2% in last 10 ticks
    if last_prices.len() >= 10 {
        let old_price = last_prices[0];
        let change_pct = (market.price - old_price) * 100 / old_price;
        if change_pct > 2 {
            fomo_triggered = true;
        }
    }
    
    // FOMO override: market buy immediately
    if fomo_triggered {
        fomo_triggered = false;
        let max_afford = account.cash / market.price;
        if max_afford > 0 {
            let buy_amt = buy_size;
            if buy_amt > max_afford { buy_amt = max_afford; }
            if buy_amt > 0 {
                orders.submit_market_buy(buy_amt);
            }
        }
        return;
    }
    
    // Main contrarian strategy
    let rsi = market.rsi_14;
    
    // Oversold: buy with limit order below price
    if rsi < 3000 && account.cash > 1000000 {
        let limit_price = market.price * 99 / 100;  // 1% below
        let max_afford = account.cash / limit_price;
        let buy_amt = buy_size;
        if buy_amt > max_afford { buy_amt = max_afford; }
        if buy_amt > 0 {
            orders.submit_limit_buy(limit_price, buy_amt);
        }
    }
    
    // Overbought: sell with limit order above price
    if rsi > 7000 && account.stock > 0 {
        let limit_price = market.price * 101 / 100;  // 1% above
        let sell_amt = sell_size;
        if sell_amt > account.stock { sell_amt = account.stock; }
        if sell_amt > 0 {
            orders.submit_limit_sell(limit_price, sell_amt);
        }
    }
}