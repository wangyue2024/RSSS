let initialized = false;
let base_spread = 0;
let order_size = 0;
let imbalance_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(2000, 10000);
        order_size = rng.rand_int(10, 50);
        imbalance_threshold = rng.rand_int(10, 30);
    }

    if !market.trading_enabled {
        return;
    }

    let current_tick = market.tick;

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let placed = my_orders.pending_placed_tick(i);
        if current_tick - placed >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    let imbalance = market.order_imbalance;
    let mid_price = market.price;
    let adjustment = 0;

    if imbalance > imbalance_threshold {
        adjustment = (imbalance * base_spread) / (100 * imbalance_threshold);
    } else if imbalance < -imbalance_threshold {
        adjustment = (imbalance * base_spread) / (100 * imbalance_threshold);
    }

    let adjusted_mid = mid_price + adjustment;
    let half_spread = base_spread / 2;
    let bid_price = adjusted_mid - half_spread;
    let ask_price = adjusted_mid + half_spread;

    if bid_price > 0 && account.cash >= bid_price * order_size {
        orders.submit_limit_buy(bid_price, order_size);
    }

    if ask_price > 0 && account.stock >= order_size {
        orders.submit_limit_sell(ask_price, order_size);
    }
}