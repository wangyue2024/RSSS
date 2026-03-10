let initialized = false;
let normal_order_size = 1000;
let fat_finger_size = 100000;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_price = market.price;
    let round_price = ((current_price + 500_000) / 1_000_000) * 1_000_000;

    let fat_finger_roll = rng.rand_int(0, 9999);
    if fat_finger_roll == 0 {
        if rng.rand_bool(50) {
            orders.submit_market_buy(fat_finger_size);
        } else {
            orders.submit_market_sell(fat_finger_size);
        }
        return;
    }

    let normal_trade_roll = rng.rand_int(0, 99);
    if normal_trade_roll == 0 {
        if rng.rand_bool(50) {
            orders.submit_limit_buy(round_price, normal_order_size);
        } else {
            orders.submit_limit_sell(round_price, normal_order_size);
        }
    }
}