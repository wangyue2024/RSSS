let initialized = false;
let target_shares = 0;
let base_lot_size = 0;
let last_trade_loss = false;
let position_avg_cost = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let risk_pct = rng.rand_int(30, 50);
        base_lot_size = account.cash * risk_pct / 100 / market.price;
        if base_lot_size < 1 { base_lot_size = 1; }
        target_shares = account.cash * 50 / 100 / market.price;
        if target_shares < 1 { target_shares = 1; }
        position_avg_cost = account.avg_cost;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.stock >= target_shares { return; }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_idx = fill_cnt - 1;
        let fill_price = my_orders.fill_price(last_idx);
        if position_avg_cost > 0 && fill_price < position_avg_cost {
            last_trade_loss = true;
        }
        position_avg_cost = account.avg_cost;
    }

    let current_lot = base_lot_size;
    if last_trade_loss {
        current_lot = current_lot * 2;
        last_trade_loss = false;
    }

    let hist_len = market.history_len();
    if hist_len < 5 { return; }

    let recent_vol = 0;
    let j = 0;
    while j < 5 {
        recent_vol += market.history_volume(hist_len - 1 - j);
        j += 1;
    }
    recent_vol = recent_vol / 5;

    let longer_vol = 0;
    let lookback = 20;
    if hist_len < lookback { lookback = hist_len; }
    let k = 0;
    while k < lookback {
        longer_vol += market.history_volume(hist_len - 1 - k);
        k += 1;
    }
    longer_vol = longer_vol / lookback;

    let volume_factor = 1;
    if recent_vol > longer_vol && longer_vol > 0 {
        volume_factor = recent_vol * 100 / longer_vol;
        if volume_factor > 300 { volume_factor = 300; }
    }

    let dynamic_size = current_lot * volume_factor / 100;
    if dynamic_size < 1 { dynamic_size = 1; }

    let remaining_target = target_shares - account.stock;
    if dynamic_size > remaining_target {
        dynamic_size = remaining_target;
    }

    let max_by_cash = account.cash / market.price;
    if dynamic_size > max_by_cash {
        dynamic_size = max_by_cash;
    }

    if dynamic_size < 1 { return; }

    let price = market.price;
    if market.bid_price_0 > 0 {
        price = market.bid_price_0 + 5_000;
    } else {
        price = price + 5_000;
    }

    orders.submit_limit_buy(price, dynamic_size);
}