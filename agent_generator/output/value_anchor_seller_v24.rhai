let initialized = false;
let fair_value = 0;
let lot_size = 0;
let price_history = [];
let fomo_triggered = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        fair_value = 100_000_000 + rng.rand_int(-2_000_000, 2_000_000);
        let five_percent_capital = account.total_equity * 5 / 100;
        if market.price > 0 {
            lot_size = five_percent_capital / market.price;
        }
        if lot_size < 1 { lot_size = 1; }
        if lot_size > 10000 { lot_size = 10000; }
        initialized = true;
    }
    
    if market.std_dev > 10_000_000 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    price_history.push(market.price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    if price_history.len() >= 3 && !fomo_triggered {
        let old_price = price_history[0];
        if old_price > 0 && market.price > old_price && (market.price - old_price) * 100 / old_price > 2 {
            fomo_triggered = true;
            orders.submit_market_buy(lot_size);
        }
    }
    
    if fomo_triggered { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.price > fair_value * 110 / 100 {
        orders.submit_limit_sell(market.price, lot_size * 3 / 2);
    } else if market.price > fair_value * 105 / 100 {
        orders.submit_limit_sell(market.price, lot_size);
    }
}