let phase = 0;
let entry_price = 0;
let entry_amount = 0;
let tp_order_id = 0;
let tp_placed_tick = 0;

fn is_order_pending(order_id) {
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        if my_orders.pending_id(i) == order_id {
            return true;
        }
        i += 1;
    }
    return false;
}

fn on_tick() {
    if !market.trading_enabled { return; }

    if phase == 0 {
        if rng.rand_bool(1) {
            entry_amount = rng.rand_int(100, 1000);
            entry_price = market.price;
            tp_order_id = orders.submit_limit_sell(entry_price * 105 / 100, entry_amount);
            tp_placed_tick = market.tick;
            phase = 1;
        }
    } else if phase == 1 {
        if is_order_pending(tp_order_id) {
            if market.tick - tp_placed_tick >= 3 {
                orders.submit_cancel(tp_order_id);
                tp_order_id = orders.submit_limit_sell(entry_price * 105 / 100, entry_amount);
                tp_placed_tick = market.tick;
            }
        } else {
            let stop_price = entry_price * 98 / 100;
            if market.price <= stop_price {
                orders.submit_market_sell(entry_amount);
                phase = 2;
            }
        }
    }
}