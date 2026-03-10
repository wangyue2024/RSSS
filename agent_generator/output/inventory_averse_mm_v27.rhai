let initialized = false;
let base_spread = 10_000;
let order_size = 100;
let inventory_skew_factor = 50;
let high_inv_threshold = 1000;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid_price = market.price;
    let half_spread = base_spread / 2;
    let inventory = account.stock;

    let bid_distance = half_spread;
    let ask_distance = half_spread;

    if inventory > high_inv_threshold {
        bid_distance = half_spread * (100 + inventory_skew_factor) / 100;
        ask_distance = half_spread * (100 - inventory_skew_factor) / 100;
    } else if inventory <= 0 {
        bid_distance = half_spread * (100 - inventory_skew_factor) / 100;
        ask_distance = half_spread * (100 + inventory_skew_factor) / 100;
    }

    let bid_price_raw = mid_price - bid_distance;
    let ask_price = mid_price + ask_distance;

    let bid_price = bid_price_raw + 1;

    if bid_price > 0 && bid_price < ask_price {
        orders.submit_limit_buy(bid_price, order_size);
        orders.submit_limit_sell(ask_price, order_size);
    }
}