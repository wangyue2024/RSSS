let initialized = false;
let stop_loss_thresh = 0;
let normal_amount = 100;
let fat_finger_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_thresh = -rng.rand_int(1_000_000, 10_000_000);
        normal_amount = rng.rand_int(50, 200);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < stop_loss_thresh {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        fat_finger_triggered = false;
        return;
    }

    if rng.rand_int(0, 9999) == 0 {
        fat_finger_triggered = true;
    }

    if fat_finger_triggered {
        if rng.rand_bool(50) {
            orders.submit_market_buy(normal_amount * 100);
        } else {
            orders.submit_market_sell(normal_amount * 100);
        }
        fat_finger_triggered = false;
    }
}