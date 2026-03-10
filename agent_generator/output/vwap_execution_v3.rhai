let target_total = 200_000;
let bought_so_far = 0;
let orders_placed = false;

fn on_tick() {
    if !market.trading_enabled { return; }

    let active_period = market.tick < market.total_ticks / 5;
    if !active_period {
        return;
    }

    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        let side = my_orders.fill_side(i);
        if side == 0 {
            bought_so_far += my_orders.fill_amount(i);
        }
        i += 1;
    }

    let pending_cnt = my_orders.pending_count();
    let idx = 0;
    while idx < pending_cnt {
        let placed = my_orders.pending_placed_tick(idx);
        if market.tick - placed > 3 {
            let oid = my_orders.pending_id(idx);
            orders.submit_cancel(oid);
        }
        idx += 1;
    }

    if bought_so_far >= target_total {
        return;
    }

    let remaining = target_total - bought_so_far;
    if remaining <= 0 {
        return;
    }

    let pending_now = my_orders.pending_count();
    if pending_now > 0 {
        return;
    }

    let history_len = market.history_len();
    if history_len == 0 {
        return;
    }

    let recent_volumes = [];
    let lookback = if history_len < 10 { history_len } else { 10 };
    let j = 0;
    while j < lookback {
        recent_volumes.push(market.history_volume(j));
        j += 1;
    }
    let avg_vol = arr_mean(recent_volumes);
    if avg_vol == 0 {
        return;
    }

    let volume_ratio = market.volume * 100 / avg_vol;
    let slice_base = remaining * 2 / 100;
    let slice_adjusted = slice_base * volume_ratio / 100;
    let slice = clamp_val(slice_adjusted, 100, remaining);

    let best_bid = market.bid_price_0;
    let price = if best_bid > 0 { best_bid } else { market.price - micros(0, 1) };

    if slice > 0 && price > 0 {
        orders.submit_limit_buy(price, slice);
        orders_placed = true;
    }
}