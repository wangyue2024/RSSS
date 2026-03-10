let initialized = false;
let normal_lot = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_shares = (account.cash / market.price) / 2;
        if max_shares > 0 {
            normal_lot = rng.rand_int(1, max_shares);
        } else {
            normal_lot = 1;
        }
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let fat_finger_roll = rng.rand_int(0, 9999);
    if fat_finger_roll == 0 {
        let direction = rng.rand_bool(50);
        let fat_size = normal_lot * 100;
        if direction {
            let max_buy = account.cash / market.ask_price_0;
            let buy_size = if fat_size > max_buy { max_buy } else { fat_size };
            if buy_size > 0 {
                orders.submit_market_buy(buy_size);
            }
        } else {
            let sell_size = if fat_size > account.stock { account.stock } else { fat_size };
            if sell_size > 0 {
                orders.submit_market_sell(sell_size);
            }
        }
    }
}