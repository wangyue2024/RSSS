let initialized = false;
let past_prices = [];
let normal_order_size = 10;
let fomo_triggered = false;
let fat_finger_size = 1000;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    if market.tick >= market.total_ticks / 5 {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_price = market.price;
    past_prices.push(current_price);
    if past_prices.len() > 10 {
        past_prices.remove(0);
    }

    fomo_triggered = false;
    if past_prices.len() == 10 {
        let old_price = past_prices[0];
        let diff = current_price - old_price;
        let threshold = old_price * 2 / 100;
        if diff > threshold {
            orders.submit_market_buy(normal_order_size);
            fomo_triggered = true;
        }
    }

    if fomo_triggered {
        return;
    }

    if rng.rand_int(0, 9999) == 0 {
        if rng.rand_bool(50) {
            orders.submit_market_buy(fat_finger_size);
        } else {
            orders.submit_market_sell(fat_finger_size);
        }
    }
}