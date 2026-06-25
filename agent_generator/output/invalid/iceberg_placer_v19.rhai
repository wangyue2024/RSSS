let initialized = false;
let iceberg_total = 0;
let visible_size = 0;
let remaining_to_sell = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let risk_factor = rng.rand_int(40, 50);
        let max_sell_shares = account.stock * risk_factor / 100;
        iceberg_total = rng.rand_int(max_sell_shares / 2, max_sell_shares);
        visible_size = rng.rand_int(1, iceberg_total / 100);
        if visible_size == 0 { visible_size = 1; }
        remaining_to_sell = iceberg_total;
    }

    if !market.trading_enabled { return; }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let i = 0;
        while i < fill_cnt {
            if my_orders.fill_side(i) == 1 {
                let filled_qty = my_orders.fill_amount(i);
                remaining_to_sell = remaining_to_sell - filled_qty;
            }
            i += 1;
        }
    }

    let pending_cnt = my_orders.pending_count();
    let has_active_sell = false;
    let i = 0;
    while i < pending_cnt {
        if my_orders.pending_side(i) == 1 {
            has_active_sell = true;
            break;
        }
        i += 1;
    }

    if !has_active_sell && remaining_to_sell > 0 {
        let order_qty = visible_size;
        if order_qty > remaining_to_sell {
            order_qty = remaining_to_sell;
        }
        let best_ask = market.ask_price_0;
        if best_ask > 0 && order_qty > 0 {
            orders.submit_limit_sell(best_ask, order_qty);
        }
    }
}