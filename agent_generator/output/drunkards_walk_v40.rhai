// Global variables persist across ticks
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    // High-Frequency Canceler: cancel any limit order pending > 3 ticks
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed = my_orders.pending_placed_tick(i);
        if market.tick - placed > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    // Random action every tick
    let roll = rng.rand_int(0, 99);
    if roll < 5 {
        // Random buy
        let qty = rng.rand_int(1, 100);
        let price_offset = rng.rand_int(-50000, 0); // up to 5 cents below
        let price = market.price + price_offset;
        if price > 0 && qty > 0 {
            orders.submit_limit_buy(price, qty);
        }
    } else if roll > 95 {
        // Random sell
        let qty = rng.rand_int(1, 100);
        let price_offset = rng.rand_int(0, 50000); // up to 5 cents above
        let price = market.price + price_offset;
        if price > 0 && qty > 0 {
            orders.submit_limit_sell(price, qty);
        }
    }
}