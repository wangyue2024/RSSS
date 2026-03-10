let target_shares = 0;
let bought_shares = 0;
let daily_target = 10000;
let slice_percent = 0;
let vwap_ref = 0;
let initialized = false;
let last_cancel_tick = -1000;

fn on_tick() {
    if !market.trading_enabled {
        return;
    }

    if !initialized {
        initialized = true;
        target_shares = daily_target;
        slice_percent = rng.rand_int(10, 30);
        vwap_ref = market.vwap;
        if vwap_ref == 0 {
            vwap_ref = market.price;
        }
    }

    let morning_limit = market.total_ticks * 20 / 100;
    if market.tick >= morning_limit {
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }

    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        if my_orders.fill_side(i) == 0 {
            bought_shares += my_orders.fill_amount(i);
        }
        i += 1;
    }

    if bought_shares >= target_shares {
        return;
    }

    if market.tick - last_cancel_tick < 10 {
        return;
    }

    let pending = my_orders.pending_count();
    i = 0;
    while i < pending {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    last_cancel_tick = market.tick;

    let remaining = target_shares - bought_shares;
    if remaining <= 0 {
        return;
    }

    let vol_lookback = 20;
    let hist_len = market.history_len();
    let periods = if hist_len < vol_lookback { hist_len } else { vol_lookback };
    let vol_sum = 0;
    i = 0;
    while i < periods {
        vol_sum += market.history_volume(i);
        i += 1;
    }
    let avg_volume = if periods > 0 { vol_sum / periods } else { 1 };

    let current_volume = if hist_len > 0 { market.history_volume(0) } else { 1 };
    let vol_ratio = current_volume * 100 / avg_volume;
    let slice_size = remaining * slice_percent / 100;
    let dynamic_slice = slice_size * vol_ratio / 100;

    let order_size = clamp_val(dynamic_slice, 1, remaining);
    if order_size <= 0 {
        return;
    }

    let price_adj = market.vwap * 9995 / 10000;
    let bid_price = market.bid_price_0;
    let limit_price = if bid_price > 0 && bid_price < price_adj { bid_price } else { price_adj };

    if limit_price <= 0 {
        return;
    }

    orders.submit_limit_buy(limit_price, order_size);
}