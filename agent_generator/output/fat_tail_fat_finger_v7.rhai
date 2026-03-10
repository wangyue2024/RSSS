let initialized = false;
let price_buffer = [];
let base_size = 100;
let jump_threshold_pct = 200;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_size = rng.rand_int(50, 200);
    }

    if !market.trading_enabled { return; }

    price_buffer.push(market.price);
    if price_buffer.len() > 10 {
        price_buffer.remove(0);
    }

    if price_buffer.len() < 10 {
        return;
    }

    let delayed_price = price_buffer[4];
    let old_price = price_buffer[9];

    let price_diff = delayed_price - old_price;
    let abs_diff = abs_val(price_diff);
    let threshold = old_price * jump_threshold_pct / 10000;

    if abs_diff > threshold && price_diff > 0 {
        orders.submit_market_buy(base_size);
        return;
    }

    let fat_finger_trigger = rng.rand_int(0, 9999) == 0;

    if fat_finger_trigger {
        let side = rng.rand_bool(50);
        let fat_size = base_size * 100;
        if side {
            orders.submit_market_buy(fat_size);
        } else {
            orders.submit_market_sell(fat_size);
        }
    }
}