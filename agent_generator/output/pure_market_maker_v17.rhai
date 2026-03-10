let initialized = false;
let spread_micros = 0;
let order_amount = 0;
let max_order_age = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(800, 3000);
        order_amount = rng.rand_int(50, 300);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        let age = market.tick - my_orders.pending_placed_tick(i);
        if age >= max_order_age {
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    let bid_price = market.price - spread_micros;
    let ask_price = market.price + spread_micros;

    if bid_price > 0 {
        orders.submit_limit_buy(bid_price, order_amount);
    }
    orders.submit_limit_sell(ask_price, order_amount);
}