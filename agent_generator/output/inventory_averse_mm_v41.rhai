let initialized = false;
let base_spread = 0;
let base_order_size = 0;
let inventory_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(5000, 20000);
        base_order_size = rng.rand_int(50, 200);
        inventory_threshold = rng.rand_int(800, 1200);
    }

    if !market.trading_enabled { return; }
    if market.tick >= market.total_ticks / 5 { return; }

    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid = market.price;
    let inv = account.stock;
    let spread = base_spread;

    let buy_dist = spread;
    let sell_dist = spread;

    let skew_factor = if inv > inventory_threshold {
        150
    } else if inv < 0 - inventory_threshold {
        50
    } else {
        100
    };

    let adjusted_buy_dist = buy_dist * skew_factor / 100;
    let adjusted_sell_dist = sell_dist * (200 - skew_factor) / 100;

    let buy_price = mid - adjusted_buy_dist;
    let sell_price = mid + adjusted_sell_dist;

    if buy_price > 0 {
        orders.submit_limit_buy(buy_price, base_order_size);
    }
    if sell_price > 0 {
        orders.submit_limit_sell(sell_price, base_order_size);
    }
}