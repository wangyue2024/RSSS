let initialized = false;
let target_position = 50_000;
let slice_size = 0;
let tick_interval = 0;
let last_order_tick = -1000;

fn on_tick() {
    if !initialized {
        if market.trading_enabled {
            let cash_shares = account.cash / market.price;
            let risk_slice = cash_shares * 50 / 100;
            slice_size = rng.rand_int(500, risk_slice);
            if slice_size < 500 {
                slice_size = 500;
            }
            tick_interval = rng.rand_int(1, 5);
            initialized = true;
        }
        return;
    }

    if !market.trading_enabled { return; }

    if market.tick >= market.total_ticks * 2 / 10 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }

    let current_tick = market.tick;
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let order_age = current_tick - my_orders.pending_placed_tick(i);
        if order_age >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if account.stock >= target_position {
        return;
    }

    if current_tick - last_order_tick >= tick_interval {
        let remaining = target_position - account.stock;
        let order_amount = slice_size;
        if order_amount > remaining {
            order_amount = remaining;
        }
        if order_amount > 0 {
            orders.submit_market_buy(order_amount);
            last_order_tick = current_tick;
        }
    }
}