let iceberg_total = 0;
let iceberg_remaining = 0;
let visible_amount = 0;
let replenish_trigger = false;
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        iceberg_total = 20000;
        iceberg_remaining = iceberg_total;
        visible_amount = iceberg_total / 100;
        if visible_amount < 1 {
            visible_amount = 1;
        }
    }

    if !market.trading_enabled {
        return;
    }

    if market.tick >= market.total_ticks / 5 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        replenish_trigger = true;
    }

    let pending_cnt = my_orders.pending_count();
    if pending_cnt == 0 && iceberg_remaining > 0 {
        let best_ask = market.ask_price_0;
        if best_ask > 0 {
            let order_amount = visible_amount;
            if iceberg_remaining < order_amount {
                order_amount = iceberg_remaining;
            }
            orders.submit_limit_sell(best_ask, order_amount);
        }
    }

    if replenish_trigger && iceberg_remaining > 0 {
        replenish_trigger = false;

        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }

        let total_filled = 0;
        let fill_i = 0;
        while fill_i < fill_cnt {
            let fill_side = my_orders.fill_side(fill_i);
            if fill_side == 1 {
                total_filled += my_orders.fill_amount(fill_i);
            }
            fill_i += 1;
        }

        iceberg_remaining -= total_filled;
        if iceberg_remaining <= 0 {
            iceberg_remaining = 0;
            return;
        }

        let best_ask = market.ask_price_0;
        if best_ask > 0 {
            let order_amount = visible_amount;
            if iceberg_remaining < order_amount {
                order_amount = iceberg_remaining;
            }
            orders.submit_limit_sell(best_ask, order_amount);
        }
    }
}