let initialized = false;
let total_to_sell = 0;
let slice_size = 0;
let stop_loss_micros = 0;
let remaining_target = 0;
let active_order_id = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        total_to_sell = rng.rand_int(200000, 500000);
        slice_size = rng.rand_int(500, 2000);
        stop_loss_micros = -1 * rng.rand_int(100000, 500000);
        remaining_target = total_to_sell;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        if oid != active_order_id {
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if account.unrealized_pnl < stop_loss_micros && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        if active_order_id != 0 {
            orders.submit_cancel(active_order_id);
            active_order_id = 0;
        }
        return;
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let j = 0;
        while j < fill_cnt {
            if my_orders.fill_side(j) == "sell" {
                let filled_qty = my_orders.fill_amount(j);
                remaining_target = remaining_target - filled_qty;
                if remaining_target < 0 {
                    remaining_target = 0;
                }
            }
            j += 1;
        }
        if active_order_id != 0 {
            orders.submit_cancel(active_order_id);
            active_order_id = 0;
        }
    }

    if remaining_target > 0 && active_order_id == 0 && market.ask_price_0 > 0 {
        let order_qty = slice_size;
        if order_qty > remaining_target {
            order_qty = remaining_target;
        }
        let oid = orders.submit_limit_sell(market.ask_price_0, order_qty);
        if oid != 0 {
            active_order_id = oid;
        }
    }
}