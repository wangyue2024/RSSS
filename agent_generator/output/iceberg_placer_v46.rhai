let initialized = false;
let panic_threshold = 0;
let iceberg_total = 0;
let small_order_size = 0;
let remaining_to_sell = 0;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        panic_threshold = -1 * rng.rand_int(10_000, 50_000);
        iceberg_total = account.stock;
        small_order_size = iceberg_total / 100;
        if small_order_size < 1 { small_order_size = 1; }
        remaining_to_sell = iceberg_total;
        initialized = true;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        let pending_cnt = my_orders.pending_count();
        let j = 0;
        while j < pending_cnt {
            let oid = my_orders.pending_id(j);
            orders.submit_cancel(oid);
            j += 1;
        }
        orders.submit_market_sell(account.stock);
        return;
    }

    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        if my_orders.fill_side(i) == 1 {
            remaining_to_sell -= my_orders.fill_amount(i);
            if remaining_to_sell < 0 { remaining_to_sell = 0; }
        }
        i += 1;
    }

    if market.tick % 50 == 0 {
        let pending_cnt = my_orders.pending_count();
        let j = 0;
        while j < pending_cnt {
            let oid = my_orders.pending_id(j);
            orders.submit_cancel(oid);
            j += 1;
        }

        if remaining_to_sell > 0 && market.ask_price_0 > 0 {
            let raw_price = market.ask_price_0;
            let round_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
            let order_amt = small_order_size;
            if order_amt > remaining_to_sell { order_amt = remaining_to_sell; }
            orders.submit_limit_sell(round_price, order_amt);
        }
    }
}