let initialized = false;
let price_history = [];
let fomo_triggered = false;

fn round_to_dollar(price) {
    let remainder = price % 1_000_000;
    if remainder >= 500_000 {
        price - remainder + 1_000_000
    } else {
        price - remainder
    }
}

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        price_history.push(market.price);
        return;
    }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    let count_pending = my_orders.pending_count();
    let i = 0;
    while i < count_pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if price_history.len() >= 5 {
        let old_price = price_history[0];
        let current_price = market.price;
        let price_change_pct = abs_val(current_price - old_price) * 100 / old_price;

        if price_change_pct > 200 && !fomo_triggered {
            fomo_triggered = true;
            let order_amount = 1000;
            orders.submit_market_buy(order_amount);
            return;
        }

        if fomo_triggered && price_change_pct <= 200 {
            fomo_triggered = false;
        }
    }

    if fomo_triggered {
        return;
    }

    let fat_finger_chance = rng.rand_int(0, 9999);
    if fat_finger_chance == 0 {
        let normal_size = 1000;
        let fat_finger_size = normal_size * 100;
        let side = rng.rand_int(0, 1);
        if side == 0 {
            orders.submit_market_buy(fat_finger_size);
        } else {
            orders.submit_market_sell(fat_finger_size);
        }
        return;
    }

    if price_history.len() >= 5 {
        let delayed_price = price_history[0];
        let rounded_price = round_to_dollar(delayed_price);
        let spread = 1_000_000;
        let order_amount = 1000;

        orders.submit_limit_buy(rounded_price - spread, order_amount);
        orders.submit_limit_sell(rounded_price + spread, order_amount);
    }
}