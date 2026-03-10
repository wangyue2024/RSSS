let initialized = false;
let spread_micros = 0;
let order_size = 0;
let last_action_tick = -1;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        spread_micros = 25000;
        order_size = 100;
    }

    if market.tick % 50 != 0 {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid_price = market.price;
    let bid_price = mid_price - spread_micros;
    let ask_price = mid_price + spread_micros;

    if bid_price > 0 && account.cash >= bid_price * order_size {
        orders.submit_limit_buy(bid_price, order_size);
    }
    if account.stock >= order_size {
        orders.submit_limit_sell(ask_price, order_size);
    }
}