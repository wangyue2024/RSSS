let initialized = false;
let prev_price = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        prev_price = market.price;
        initialized = true;
        return;
    }

    let current_price = market.price;
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let price_change = current_price - prev_price;
    
    if price_change < 0 {
        let target_price = current_price * 999 / 1000;
        let rounded_price = ((target_price + 500_000) / 1_000_000) * 1_000_000;
        if rounded_price >= current_price {
            rounded_price -= 1_000_000;
        }
        orders.submit_limit_buy(rounded_price, 100);
    } else if price_change > 0 {
        let target_price = current_price * 1001 / 1000;
        let rounded_price = ((target_price + 500_000) / 1_000_000) * 1_000_000;
        if rounded_price <= current_price {
            rounded_price += 1_000_000;
        }
        orders.submit_limit_sell(rounded_price, 100);
    }

    prev_price = current_price;
}