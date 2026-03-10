let initialized = false;
let lazy_timer = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 { return; }
    
    if market.tick % 50 != 0 { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let rand_val = rng.rand_int(0, 99);
    
    if rand_val < 5 {
        let qty = rng.rand_int(1, 10);
        let price_offset = rng.rand_int(-5, 5) * 1_000_000;
        let price = market.price + price_offset;
        if price > 0 {
            orders.submit_limit_buy(price, qty);
        }
    }
    
    if rand_val > 95 && market.price > account.avg_cost {
        let max_qty = account.stock;
        if max_qty > 0 {
            let qty = rng.rand_int(1, max_qty);
            let price_offset = rng.rand_int(0, 10) * 1_000_000;
            let price = market.price + price_offset;
            orders.submit_limit_sell(price, qty);
        }
    }
}