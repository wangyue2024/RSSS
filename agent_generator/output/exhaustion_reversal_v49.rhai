let initialized = false;
let last_decision_tick = 0;
let lot_size = 0;
let order_tracker = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_capital_5pct = account.total_equity * 5 / 100;
        let max_shares = max_capital_5pct / market.price;
        if max_shares > 0 {
            lot_size = rng.rand_int(1, max_shares);
        } else {
            lot_size = 1;
        }
        last_decision_tick = market.tick;
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;

    let i = 0;
    while i < my_orders.pending_count() {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if (current_tick - last_decision_tick) < 50 { return; }
    last_decision_tick = current_tick;

    let std_dev_threshold = market.price * 5 / 1000;
    if market.std_dev > std_dev_threshold { return; }

    let vol_history_len = market.history_len();
    if vol_history_len < 5 { return; }

    let recent_vols = [];
    let j = 0;
    while j < 5 {
        recent_vols.push(market.history_volume(j));
        j += 1;
    }
    let avg_recent_vol = arr_mean(recent_vols);
    let vol_exhaustion = market.volume < avg_recent_vol * 10 / 100;

    let high_above_ma = market.high_20 > market.ma_60;

    if vol_exhaustion && high_above_ma {
        let price_target = market.bid_price_0 - 100;
        if price_target > 0 {
            orders.submit_limit_sell(price_target, lot_size);
        }
    }
}