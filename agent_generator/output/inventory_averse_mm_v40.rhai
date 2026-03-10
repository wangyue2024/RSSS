let initialized = false;
let base_spread = 0;
let order_size = 0;

fn on_tick() {
    if (!initialized) {
        initialized = true;
        base_spread = rng.rand_int(50_000, 200_000);
        order_size = rng.rand_int(50, 200);
    }

    if (!market.trading_enabled) { return; }

    if (market.tick % 50 != 0) { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while (i < count) {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid = (market.bid_price_0 + market.ask_price_0) / 2;
    let half_spread = base_spread / 2;
    let inv = account.stock;

    let skew_factor = clamp_val(inv / 10, -10, 10);
    let inv_adjustment = skew_factor * (half_spread / 10);

    let raw_bid = mid - half_spread - inv_adjustment;
    let raw_ask = mid + half_spread - inv_adjustment;

    let bid_price = raw_bid + 1;
    let ask_price = raw_ask;

    if (bid_price > 0 && ask_price > bid_price) {
        orders.submit_limit_buy(bid_price, order_size);
        orders.submit_limit_sell(ask_price, order_size);
    }
}