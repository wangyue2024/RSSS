let price_history = [];
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled {
        return;
    }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() < 5 {
        return;
    }
    
    let old_price = price_history[0];
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let r = rng.rand_int(0, 99);
    
    if r < 5 {
        let qty = rng.rand_int(1, 100);
        let offset = rng.rand_int(-10000, 10000);
        let order_price = old_price + offset;
        if order_price < 1 {
            order_price = 1;
        }
        orders.submit_limit_buy(order_price, qty);
    } else if r > 95 {
        let qty = rng.rand_int(1, 100);
        let offset = rng.rand_int(-10000, 10000);
        let order_price = old_price + offset;
        if order_price < 1 {
            order_price = 1;
        }
        orders.submit_limit_sell(order_price, qty);
    }
}