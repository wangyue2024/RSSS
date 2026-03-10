let initialized = false;
let target_position = 0;
let slice_size = 0;
let ticks_between = 0;
let last_order_tick = 0;
let risk_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        target_position = 50000;
        let max_slice_value = account.total_equity * 5 / 100;
        let max_slice_shares = max_slice_value / market.price;
        if max_slice_shares < 1 {
            max_slice_shares = 1;
        }
        slice_size = rng.rand_int(1, max_slice_shares);
        ticks_between = rng.rand_int(5, 20);
        risk_threshold = rng.rand_int(50000, 200000);
        last_order_tick = -ticks_between;
    }

    if !market.trading_enabled {
        return;
    }

    if market.std_dev > risk_threshold {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_position = account.stock;
    if current_position >= target_position {
        return;
    }

    if market.tick - last_order_tick < ticks_between {
        return;
    }

    let remaining = target_position - current_position;
    let order_amount = slice_size;
    if order_amount > remaining {
        order_amount = remaining;
    }

    if order_amount <= 0 {
        return;
    }

    orders.submit_market_buy(order_amount);
    last_order_tick = market.tick;
}