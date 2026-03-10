let initialized = false;
let lot_size = 0;
let max_risk_price_move = 0;
let active_period_end = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let risk_cap = account.total_equity * 5 / 100;
        let shares_from_cap = risk_cap / market.price;
        if shares_from_cap < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, shares_from_cap);
        }
        max_risk_price_move = market.price * 5 / 100;
        active_period_end = market.total_ticks / 5;
    }

    if !market.trading_enabled {
        return;
    }

    if market.tick >= active_period_end {
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }

    if market.std_dev > max_risk_price_move {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }

    let history_len = market.history_len();
    if history_len < 5 {
        return;
    }
    let recent_volumes = [];
    let idx = 0;
    while idx < 5 {
        recent_volumes.push(market.history_volume(idx));
        idx += 1;
    }
    let avg_recent_volume = arr_mean(recent_volumes);
    let volume_exhausted = avg_recent_volume > 0 && market.volume < avg_recent_volume * 10 / 100;
    let price_high_above_ma = market.price > market.ma_60;

    if volume_exhausted && price_high_above_ma && account.stock > 0 && market.price > account.avg_cost {
        let sell_amount = if lot_size > account.stock { account.stock } else { lot_size };
        if sell_amount > 0 {
            orders.submit_limit_sell(market.price, sell_amount);
        }
    }
}