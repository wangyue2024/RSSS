let initialized = false;
let decision_interval = 50;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
    }
    
    if market.tick % decision_interval != 0 {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let rand_val = rng.rand_int(0, 99);
    
    if rand_val < 5 {
        let qty = rng.rand_int(1, 100);
        let price_offset = rng.rand_int(-5000, 5000);
        let target_price = market.price + price_offset;
        if target_price < 1 {
            target_price = 1;
        }
        orders.submit_limit_buy(target_price, qty);
    } else if rand_val > 95 {
        if account.stock > 0 {
            let qty = rng.rand_int(1, 100);
            let sell_qty = qty;
            if sell_qty > account.stock {
                sell_qty = account.stock;
            }
            let price_offset = rng.rand_int(-5000, 5000);
            let target_price = market.price + price_offset;
            if target_price < 1 {
                target_price = 1;
            }
            orders.submit_limit_sell(target_price, sell_qty);
        }
    }
}