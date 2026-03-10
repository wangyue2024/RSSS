let initialized = false;
let buy_threshold = 5;
let sell_threshold = 95;
let max_offset_micros = 200_000;
let max_qty = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        buy_threshold = 5;
        sell_threshold = 95;
        max_offset_micros = 200_000;
        max_qty = 100;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let roll = rng.rand_int(0, 99);
    
    if roll < buy_threshold {
        let offset = rng.rand_int(-max_offset_micros, max_offset_micros);
        let price = market.price + offset;
        if price < 1 { price = 1; }
        let qty = rng.rand_int(1, max_qty);
        orders.submit_limit_buy(price, qty);
    } else if roll > sell_threshold {
        let offset = rng.rand_int(-max_offset_micros, max_offset_micros);
        let price = market.price + offset;
        if price < 1 { price = 1; }
        let qty = rng.rand_int(1, max_qty);
        orders.submit_limit_sell(price, qty);
    }
}