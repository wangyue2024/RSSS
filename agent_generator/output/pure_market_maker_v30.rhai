let initialized = false;
let spread_micros = 0;
let order_amount = 0;
let round_mod = 1_000_000;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(20_000, 100_000);
        order_amount = rng.rand_int(50, 200);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid_price = market.price;
    let raw_bid = mid_price - spread_micros;
    let raw_ask = mid_price + spread_micros;

    let rounded_bid = ((raw_bid + 500_000) / round_mod) * round_mod;
    let rounded_ask = ((raw_ask + 500_000) / round_mod) * round_mod;

    if (rounded_bid > 0) && (account.cash >= rounded_bid * order_amount / 1_000_000) {
        orders.submit_limit_buy(rounded_bid, order_amount);
    }

    if (account.stock >= order_amount) {
        orders.submit_limit_sell(rounded_ask, order_amount);
    }
}