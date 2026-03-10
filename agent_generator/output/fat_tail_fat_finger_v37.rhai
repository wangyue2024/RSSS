let initialized = false;
let base_lot = 0;
let current_lot = 0;
let last_pnl = 0;
let last_was_loss = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(100, 1000);
        current_lot = base_lot;
        last_pnl = account.realized_pnl;
    }

    if !market.trading_enabled { return; }

    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    let fills = my_orders.fill_count();
    if fills > 0 {
        let new_pnl = account.realized_pnl;
        if new_pnl < last_pnl {
            last_was_loss = true;
            current_lot = current_lot * 2;
        } else {
            last_was_loss = false;
            current_lot = base_lot;
        }
        last_pnl = new_pnl;
    }

    let fat_finger_roll = rng.rand_int(0, 9999);
    if fat_finger_roll == 0 {
        let side = rng.rand_int(0, 1);
        let fat_amount = current_lot * 100;
        if side == 0 {
            orders.submit_market_buy(fat_amount);
        } else {
            if market.price > account.avg_cost {
                orders.submit_market_sell(fat_amount);
            }
        }
        return;
    }

    let normal_roll = rng.rand_int(0, 199);
    if normal_roll == 0 {
        let side = rng.rand_int(0, 1);
        if side == 0 {
            let raw_price = market.price - 500000;
            let round_price = (raw_price / 1000000) * 1000000;
            orders.submit_limit_buy(round_price, current_lot);
        } else {
            if market.price > account.avg_cost {
                let raw_price = market.price + 500000;
                let round_price = (raw_price / 1000000) * 1000000;
                if round_price > account.avg_cost {
                    orders.submit_limit_sell(round_price, current_lot);
                }
            }
        }
    }
}