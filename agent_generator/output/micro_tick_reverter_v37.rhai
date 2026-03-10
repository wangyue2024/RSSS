let price_buffer = [];
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    price_buffer.push(current_price);
    
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
    }
    
    if price_buffer.len() == 5 {
        let old_price = price_buffer[0];
        let price_change = current_price - old_price;
        let base = 1_000_000;
        let half_base = 500_000;
        
        if price_change < 0 {
            let raw_target = old_price + price_change * 95 / 100;
            let rounded_target = ((raw_target + half_base) / base) * base;
            let buy_price = rounded_target - 100_000;
            if buy_price > 0 {
                orders.submit_limit_buy(buy_price, 100);
            }
        } else if price_change > 0 {
            let raw_target = old_price + price_change * 105 / 100;
            let rounded_target = ((raw_target + half_base) / base) * base;
            let sell_price = rounded_target + 100_000;
            orders.submit_limit_sell(sell_price, 100);
        }
    }
}