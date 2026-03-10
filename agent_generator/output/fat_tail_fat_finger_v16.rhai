let initialized = false;
let last_eval_tick = -1;
let normal_size = 100;
let fat_finger_size = 10000;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_eval_tick = market.tick;
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;
    let since_last_eval = current_tick - last_eval_tick;

    let fat_finger_chance = rng.rand_int(0, 9999);
    if fat_finger_chance == 0 {
        if rng.rand_bool(50) {
            orders.submit_market_buy(fat_finger_size);
        } else {
            orders.submit_market_sell(fat_finger_size);
        }
        return;
    }

    if market.history_len() >= 5 {
        let price_now = market.price;
        let price_5_ago = market.history_price(5);
        let price_jump_percent = (price_now - price_5_ago) * 10000 / price_5_ago;
        if price_jump_percent > 200 {
            orders.submit_market_buy(normal_size);
            last_eval_tick = current_tick;
            return;
        }
    }

    if since_last_eval >= 50 {
        last_eval_tick = current_tick;
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }

        if rng.rand_bool(50) {
            orders.submit_market_buy(normal_size);
        } else {
            orders.submit_market_sell(normal_size);
        }
    }
}