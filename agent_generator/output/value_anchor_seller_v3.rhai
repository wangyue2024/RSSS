let initialized = false;
let fair_value = 0;
let panic_threshold = 0;
let lot_size_percent = 0;
let recent_prices = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        fair_value = 100_000_000 + rng.rand_int(-5_000_000, 5_000_000);
        panic_threshold = -rng.rand_int(10_000, 50_000);
        lot_size_percent = rng.rand_int(30, 50);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    recent_prices.push(market.price);
    if recent_prices.len() > 10 {
        recent_prices.remove(0);
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if recent_prices.len() >= 5 {
        let old_price = recent_prices[recent_prices.len() - 5];
        let jump_pct = (market.price - old_price) * 10000 / old_price;
        if jump_pct > 200 {
            fomo_triggered = true;
            let buy_amount = account.cash * lot_size_percent / 100 / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        fomo_triggered = false;
        return;
    }
    
    if fomo_triggered { return; }
    
    let level1 = fair_value * 105 / 100;
    let level2 = fair_value * 110 / 100;
    
    if market.price > level2 && account.stock > 0 {
        let sell_amount = account.stock * lot_size_percent / 100;
        if sell_amount > 0 {
            orders.submit_limit_sell(market.bid_price_0, sell_amount);
        }
    } else if market.price > level1 && account.stock > 0 {
        let sell_amount = account.stock * (lot_size_percent / 2) / 100;
        if sell_amount > 0 {
            orders.submit_limit_sell(market.bid_price_0, sell_amount);
        }
    }
}