let initialized = false;
let recent_prices = [];
let normal_order_size = 100;
let fomo_triggered = false;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    recent_prices.push(market.price);
    if recent_prices.len() > 5 {
        recent_prices.remove(0);
    }

    if recent_prices.len() == 5 {
        let min_price = recent_prices[0];
        let idx = 1;
        while idx < 5 {
            if recent_prices[idx] < min_price {
                min_price = recent_prices[idx];
            }
            idx += 1;
        }
        if market.price * 100 > min_price * 102 {
            fomo_triggered = true;
            orders.submit_market_buy(normal_order_size);
        }
    }

    if !fomo_triggered {
        if rng.rand_int(0, 9999) == 0 {
            if rng.rand_bool(50) {
                orders.submit_market_buy(normal_order_size * 100);
            } else {
                orders.submit_market_sell(normal_order_size * 100);
            }
        }
    }
}