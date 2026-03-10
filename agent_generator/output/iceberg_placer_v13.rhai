let initialized = false;
let iceberg_total = 0;
let iceberg_remaining = 0;
let iceberg_chunk = 0;
let my_order_id = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        iceberg_total = (account.stock * 5) / 10;
        iceberg_remaining = iceberg_total;
        iceberg_chunk = (iceberg_total * 1) / 100;
        if iceberg_chunk < 1 { iceberg_chunk = 1; }
    }

    if !market.trading_enabled { return; }

    let i = 0;
    let pending_cnt = my_orders.pending_count();
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if iceberg_remaining <= 0 { return; }
    if market.price <= account.avg_cost { return; }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        iceberg_remaining = iceberg_remaining - my_orders.fill_amount(0);
    }

    if iceberg_remaining <= 0 { return; }

    let sell_amount = iceberg_chunk;
    if sell_amount > iceberg_remaining { sell_amount = iceberg_remaining; }
    if market.ask_price_0 > 0 && sell_amount > 0 {
        orders.submit_limit_sell(market.ask_price_0, sell_amount);
    }
}