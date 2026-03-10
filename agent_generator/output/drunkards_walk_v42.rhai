let initialized = false;
let buy_threshold = 0;
let sell_threshold = 0;
let max_qty = 0;
let max_offset = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        buy_threshold = 5;
        sell_threshold = 95;
        max_qty = 100;
        max_offset = 5000;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let r = rng.rand_int(0, 99);
    
    if r < buy_threshold {
        let qty = rng.rand_int(1, max_qty);
        let offset = rng.rand_int(-max_offset, max_offset);
        let price = market.price + offset + 1;
        if price > 0 {
            orders.submit_limit_buy(price, qty);
        }
    } else if r > sell_threshold {
        let qty = rng.rand_int(1, max_qty);
        let offset = rng.rand_int(-max_offset, max_offset);
        let price = market.price + offset;
        if price > 0 {
            orders.submit_limit_sell(price, qty);
        }
    }
}