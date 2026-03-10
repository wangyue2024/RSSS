let initialized = false;
let base_order_size = 1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_order_size = rng.rand_int(500, 1500);
    }

    if !market.trading_enabled { return; }

    if market.tick % 50 != 0 { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let fat_finger_chance = rng.rand_int(0, 9999);
    if fat_finger_chance == 0 {
        let order_size = base_order_size * 100;
        if rng.rand_bool(50) {
            orders.submit_market_buy(order_size);
        } else {
            orders.submit_market_sell(order_size);
        }
    }
}