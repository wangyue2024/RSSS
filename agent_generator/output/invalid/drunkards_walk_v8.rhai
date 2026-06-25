let initialized = false;
let lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size = rng.rand_int(100, 500);
    }
    
    if !market.trading_enabled { return; }
    if market.tick >= market.total_ticks / 5 { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let roll = rng.rand_int(0, 99);
    
    if roll < 5 {
        let qty = rng.rand_int(1, lot_size);
        let offset = rng.rand_int(0, 100000);
        let price = market.price + offset;
        if price > 0 {
            orders.submit_limit_buy(price, qty);
        }
    } else if roll > 95 {
        if account.stock > 0 {
            let qty = rng.rand_int(1, lot_size);
            let qty = clamp_val(qty, 1, account.stock);
            let offset = rng.rand_int(0, 100000);
            let price = market.price - offset;
            if price > 0 {
                orders.submit_limit_sell(price, qty);
            }
        }
    }
}