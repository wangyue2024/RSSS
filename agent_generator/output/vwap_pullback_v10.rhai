let initialized = false;
let threshold_pct = 0;
let order_amount = 0;
let last_decision_tick = -50;

fn on_tick() {
    if !initialized {
        initialized = true;
        threshold_pct = rng.rand_int(50, 300);
        order_amount = rng.rand_int(10, 50);
    }
    
    if !market.trading_enabled { return; }
    
    if (market.tick - last_decision_tick) % 50 != 0 {
        return;
    }
    last_decision_tick = market.tick;
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.price == 0 || market.vwap == 0 {
        return;
    }
    
    let threshold = market.vwap * threshold_pct / 10000;
    let diff = market.vwap - market.price;
    
    if diff > threshold && account.cash > 1_000_000 {
        let raw_price = market.price;
        let rounded_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
        let final_price = rounded_price + 1;
        
        if final_price <= market.price {
            orders.submit_limit_buy(final_price, order_amount);
        } else {
            orders.submit_limit_buy(market.price, order_amount);
        }
    } else if diff < 0 && account.stock > 0 {
        let raw_price = market.price;
        let rounded_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
        let final_price = rounded_price;
        
        if final_price >= market.price {
            orders.submit_limit_sell(final_price, order_amount);
        } else {
            orders.submit_limit_sell(market.price, order_amount);
        }
    }
}