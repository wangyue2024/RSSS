let initialized = false;
let last_action_tick = -1;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
    }
    
    if market.tick % 50 != 0 {
        return;
    }
    
    let rand_val = rng.rand_int(0, 99);
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if rand_val < 5 {
        let qty = rng.rand_int(1, 100);
        let price_offset = rng.rand_int(-1000, 1000);
        let bid_price = market.price + price_offset + 1;
        orders.submit_limit_buy(bid_price, qty);
    } else if rand_val > 95 {
        let qty = rng.rand_int(1, 100);
        let price_offset = rng.rand_int(-1000, 1000);
        let ask_price = market.price + price_offset;
        orders.submit_limit_sell(ask_price, qty);
    }
}