let last_price = 0;
let initialized = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        last_price = market.price;
        return;
    }
    
    if market.tick >= market.total_ticks / 5 {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    let price_change = current_price - last_price;
    
    if price_change < 0 {
        let target_price = current_price - 50000;
        let rounded_price = ((target_price + 500000) / 1_000_000) * 1_000_000;
        orders.submit_limit_buy(rounded_price, 100);
    } else if price_change > 0 {
        let target_price = current_price + 50000;
        let rounded_price = ((target_price + 500000) / 1_000_000) * 1_000_000;
        orders.submit_limit_sell(rounded_price, 100);
    }
    
    last_price = current_price;
}