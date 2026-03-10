let base_amount = 100;
let fat_finger_triggered = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    if market.tick >= market.total_ticks / 5 { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if !fat_finger_triggered {
        if rng.rand_int(0, 9999) == 0 {
            fat_finger_triggered = true;
            let fat_amount = base_amount * 100;

            if rng.rand_bool(50) {
                orders.submit_market_buy(fat_amount);
            } else {
                orders.submit_market_sell(fat_amount);
            }
        }
    }
}