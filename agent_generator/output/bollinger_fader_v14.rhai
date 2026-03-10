let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.tick >= market.total_ticks / 5 { return; }

    if market.ma_20 == 0 || market.std_dev == 0 { return; }

    let lower_band = market.ma_20 - 2 * market.std_dev;
    let upper_band = market.ma_20 + 2 * market.std_dev;

    if lower_band > 0 && account.cash > lower_band {
        orders.submit_limit_buy(lower_band, 1000);
    }

    if upper_band > account.avg_cost && account.stock >= 1000 {
        orders.submit_limit_sell(upper_band, 1000);
    }
}