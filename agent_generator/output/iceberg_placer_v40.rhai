let initialized = false;
let iceberg_total = 0;
let tip_size = 0;
let panic_threshold = 0;
let last_order_placed_tick = -1;
let current_order_id = -1;
let panic_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        iceberg_total = account.stock * 3 / 4;
        tip_size = iceberg_total / 200;
        if tip_size < 1 { tip_size = 1; }
        panic_threshold = -rng.rand_int(500_000, 2_000_000);
    }

    if !market.trading_enabled { return; }

    if panic_triggered {
        return;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        panic_triggered = true;
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        if oid == current_order_id {
            let placed_tick = my_orders.pending_placed_tick(i);
            if market.tick - placed_tick >= 3 {
                orders.submit_cancel(oid);
                current_order_id = -1;
            }
            break;
        }
        i += 1;
    }

    let filled_this_tick = false;
    let fill_cnt = my_orders.fill_count();
    let j = 0;
    while j < fill_cnt {
        let fill_id = my_orders.fill_id(j);
        if fill_id == current_order_id {
            filled_this_tick = true;
            iceberg_total -= my_orders.fill_amount(j);
            if iceberg_total < 0 { iceberg_total = 0; }
            current_order_id = -1;
            break;
        }
        j += 1;
    }

    let pending_order_exists = false;
    let k = 0;
    while k < my_orders.pending_count() {
        if my_orders.pending_id(k) == current_order_id {
            pending_order_exists = true;
            break;
        }
        k += 1;
    }

    if (!pending_order_exists || filled_this_tick) && iceberg_total > 0 && current_order_id == -1 {
        let ask = market.ask_price_0;
        if ask > 0 {
            let sell_amount = tip_size;
            if sell_amount > iceberg_total { sell_amount = iceberg_total; }
            orders.submit_limit_sell(ask, sell_amount);
            current_order_id = -1;
            last_order_placed_tick = market.tick;
        }
    }
}