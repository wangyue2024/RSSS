let initialized = false;
let total_to_sell = 0;
let slice_size = 0;
let panic_threshold = 0;
let last_order_filled = false;

fn on_tick() {
    if !initialized {
        total_to_sell = account.stock;
        slice_size = total_to_sell * 1 / 100;
        if slice_size < 1 { slice_size = 1; }
        panic_threshold = -rng.rand_int(5_000, 25_000);
        initialized = true;
    }

    if !market.trading_enabled { return; }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        total_to_sell = 0;
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        last_order_filled = true;
        let i = 0;
        while i < fill_cnt {
            if my_orders.fill_side(i) == 1 {
                total_to_sell -= my_orders.fill_amount(i);
            }
            i += 1;
        }
    }

    let pending_cnt = my_orders.pending_count();
    if (last_order_filled || pending_cnt == 0) && total_to_sell > 0 {
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        if market.ask_price_0 > account.avg_cost {
            let sell_qty = slice_size;
            if sell_qty > total_to_sell { sell_qty = total_to_sell; }
            if sell_qty > 0 {
                orders.submit_limit_sell(market.ask_price_0, sell_qty);
            }
        }
        last_order_filled = false;
    }
}