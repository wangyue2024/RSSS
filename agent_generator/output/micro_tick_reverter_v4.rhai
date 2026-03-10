let initialized = false;
let prev_price = 0;

fn on_tick() {
    if !initialized {
        prev_price = market.price;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 {
        prev_price = market.price;
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let price_change = market.price - prev_price;
    let offset = 100000;
    
    if price_change < 0 {
        let target_price = market.price - offset;
        let rounded_price = ((target_price + 500000) / 1000000) * 1000000;
        let amount = 100;
        orders.submit_limit_buy(rounded_price, amount);
    } else if price_change > 0 {
        let target_price = market.price + offset;
        let rounded_price = ((target_price + 500000) / 1000000) * 1000000;
        let amount = 100;
        orders.submit_limit_sell(rounded_price, amount);
    }
    
    prev_price = market.price;
}