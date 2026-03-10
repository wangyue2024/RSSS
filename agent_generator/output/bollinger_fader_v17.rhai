let initialized = false;
let order_amount = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        order_amount = rng.rand_int(50, 200);
    }

    if !market.trading_enabled { return; }

    // Morning Person: only trade in first 20% of session
    if market.tick * 5 >= market.total_ticks { return; }

    // Cancel all existing orders each tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    // Calculate Bollinger Bands
    let upper_band = market.ma_20 + 2 * market.std_dev;
    let lower_band = market.ma_20 - 2 * market.std_dev;

    // Place limit buy at lower band
    if lower_band > 0 {
        orders.submit_limit_buy(lower_band, order_amount);
    }

    // Stubborn Holder: only sell if price > average cost
    if upper_band > account.avg_cost && account.stock > 0 {
        orders.submit_limit_sell(upper_band, order_amount);
    }
}