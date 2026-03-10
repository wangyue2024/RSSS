let initialized = false;
let lot_size = 0;
let stop_loss_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_lot_value = account.total_equity * 5 / 100;
        let max_shares = max_lot_value / market.price;
        if max_shares > 0 {
            lot_size = rng.rand_int(1, max_shares);
        } else {
            lot_size = 1;
        }
        stop_loss_ticks = rng.rand_int(3, 8);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let volatility_too_high = market.std_dev > (market.price * 200) / 10000;
    if volatility_too_high { return; }

    let breakout_signal = market.price > market.high_20;
    let no_position = account.stock == 0;

    if breakout_signal && no_position && lot_size > 0 {
        orders.submit_market_buy(lot_size);
    }

    if account.stock > 0 {
        let stop_price = account.avg_cost - stop_loss_ticks * 10_000;
        orders.submit_limit_sell(stop_price, account.stock);
    }
}