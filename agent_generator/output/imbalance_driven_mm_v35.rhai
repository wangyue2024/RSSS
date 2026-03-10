let initialized = false;
let base_spread_bps = 20;
let order_size = 100;
let imbalance_threshold = 50;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread_bps = rng.rand_int(15, 30);
        imbalance_threshold = rng.rand_int(40, 80);
    }

    if !market.trading_enabled { return; }

    if market.tick % 50 != 0 { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid_price = market.price;
    let imbalance = market.order_imbalance;

    let spread_offset = (mid_price * base_spread_bps) / 10000;
    let half_spread = spread_offset / 2;

    let imbalance_factor = clamp_val(imbalance, -100, 100);
    let price_shift = (mid_price * imbalance_factor) / 20000;

    let bid_price = mid_price - half_spread + price_shift;
    let ask_price = mid_price + half_spread + price_shift;

    if bid_price > 0 && account.cash > bid_price * order_size {
        orders.submit_limit_buy(bid_price, order_size);
    }

    if ask_price > 0 && account.stock >= order_size {
        orders.submit_limit_sell(ask_price, order_size);
    }
}