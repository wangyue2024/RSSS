let initialized = false;
let lot_size = 0;
let last_decision_tick = -50;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        last_decision_tick = market.tick;
    }

    if market.tick - last_decision_tick < 50 { return; }
    last_decision_tick = market.tick;

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let five_percent_cap = account.total_equity * 5 / 100;
    if market.price == 0 || five_percent_cap == 0 { return; }
    let max_shares = five_percent_cap / market.price;
    if max_shares <= 0 { return; }
    lot_size = rng.rand_int(1, max_shares);

    let dev_threshold = market.ma_20 * 10 / 100;
    if market.std_dev > dev_threshold { return; }

    let lower_band = market.ma_20 - 2 * market.std_dev;
    let upper_band = market.ma_20 + 2 * market.std_dev;

    if lower_band > 0 && lot_size > 0 {
        orders.submit_limit_buy(lower_band, lot_size);
    }
    if upper_band > 0 && account.stock >= lot_size && lot_size > 0 {
        orders.submit_limit_sell(upper_band, lot_size);
    }
}