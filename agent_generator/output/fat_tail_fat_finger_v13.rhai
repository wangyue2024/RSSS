let initialized = false;
let panic_threshold = 0;
let normal_amount = 100;
let fat_finger_chance = 1;
let in_morning = false;

fn on_tick() {
    if !initialized {
        panic_threshold = -rng.rand_int(500_000, 5_000_000);
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    in_morning = market.tick < market.total_ticks / 5;
    if !in_morning { return; }

    if account.unrealized_pnl < panic_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    if rng.rand_int(0, 9999) < fat_finger_chance {
        let fat_amount = normal_amount * 100;
        if rng.rand_bool(50) {
            orders.submit_market_buy(fat_amount);
        } else {
            orders.submit_market_sell(fat_amount);
        }
    }
}