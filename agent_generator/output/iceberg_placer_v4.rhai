let initialized = false;
let iceberg_total = 0;
let tip_size = 0;
let remaining_to_sell = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let risk_factor = rng.rand_int(50, 100);
        let cash_for_trade = account.cash * risk_factor / 100;
        let price_estimate = market.ask_price_0;
        if price_estimate == 0 { price_estimate = 1_000_000; }
        iceberg_total = cash_for_trade / price_estimate;
        if iceberg_total < 1 { iceberg_total = 1; }
        tip_size = iceberg_total / 100;
        if tip_size < 1 { tip_size = 1; }
        remaining_to_sell = iceberg_total;
    }

    if !market.trading_enabled { return; }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let fill_count = my_orders.fill_count();
    if fill_count > 0 {
        let j = 0;
        while j < fill_count {
            let fill_side = my_orders.fill_side(j);
            let fill_amount = my_orders.fill_amount(j);
            if fill_side == 1 {
                remaining_to_sell -= fill_amount;
            }
            j += 1;
        }
    }

    if remaining_to_sell <= 0 { return; }

    let raw_price = market.ask_price_0;
    if raw_price == 0 { return; }

    let rounded_price = (raw_price + 500_000) / 1_000_000 * 1_000_000;
    let order_amount = tip_size;
    if order_amount > remaining_to_sell {
        orders.submit_limit_sell(rounded_price, remaining_to_sell);
    } else {
        orders.submit_limit_sell(rounded_price, order_amount);
    }
}