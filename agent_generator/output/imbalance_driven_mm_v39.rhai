let initialized = false;
let spread = 0;
let base_order_size = 0;
let fomo_triggered = false;
let fomo_cooldown = 0;
let recent_prices = [];
let price_jump_threshold = 0;
let max_position = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread = rng.rand_int(2000, 8000);
        base_order_size = rng.rand_int(80, 150);
        price_jump_threshold = 20000;
        max_position = rng.rand_int(800, 1200);
        recent_prices.push(market.price);
    }

    if !market.trading_enabled {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    recent_prices.push(market.price);
    if recent_prices.len() > 10 {
        recent_prices.remove(0);
    }

    if recent_prices.len() >= 5 {
        let min_price = recent_prices[0];
        let j = 1;
        while j < recent_prices.len() {
            if recent_prices[j] < min_price {
                min_price = recent_prices[j];
            }
            j += 1;
        }
        let current = recent_prices[recent_prices.len() - 1];
        if current > min_price && (current - min_price) * 100 / min_price > price_jump_threshold / 10000 {
            fomo_triggered = true;
            fomo_cooldown = 20;
        }
    }

    if fomo_cooldown > 0 {
        fomo_cooldown -= 1;
        if fomo_triggered && account.stock < max_position {
            let buy_amt = base_order_size * 2;
            if buy_amt > 0 {
                orders.submit_market_buy(buy_amt);
            }
        }
        if fomo_cooldown <= 0 {
            fomo_triggered = false;
        }
        return;
    }

    let imbalance = market.order_imbalance;
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let adjustment = 0;

    if imbalance > 20 {
        adjustment = imbalance * spread / 100;
    } else if imbalance < -20 {
        adjustment = imbalance * spread / 100;
    }

    let bid_price = mid_price - spread / 2 + adjustment;
    let ask_price = mid_price + spread / 2 + adjustment;

    if bid_price > 0 && account.cash > bid_price * base_order_size && account.stock < max_position {
        orders.submit_limit_buy(bid_price, base_order_size);
    }

    if ask_price > 0 && account.stock > 0 {
        orders.submit_limit_sell(ask_price, base_order_size);
    }
}