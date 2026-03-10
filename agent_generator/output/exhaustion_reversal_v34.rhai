let initialized = false;
let risk_multiplier = 0;
let lot_size_multiplier = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_multiplier = rng.rand_int(40, 60);
        lot_size_multiplier = rng.rand_int(3, 6);
    }

    if !market.trading_enabled { return; }

    if market.tick % 50 != 0 { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let hist_len = market.history_len();
    if hist_len < 20 { return; }

    let volume_arr = [];
    let j = 0;
    while j < 20 && j < hist_len {
        volume_arr.push(market.history_volume(j));
        j += 1;
    }
    let avg_vol_20 = arr_mean(volume_arr);
    if avg_vol_20 <= 0 { return; }

    let vol_ratio = market.volume * 1000 / avg_vol_20;

    let condition_trigger = market.price > market.ma_60 && vol_ratio < 100;

    if condition_trigger && account.stock > 0 {
        let base_shares = account.stock * risk_multiplier / 100;
        let max_trade = base_shares * lot_size_multiplier;
        let sell_amount = clamp_val(max_trade, 1, account.stock);
        orders.submit_market_sell(sell_amount);
    }

    if condition_trigger && account.stock == 0 {
        let max_buy_value = account.cash * risk_multiplier / 100;
        let shares_to_buy = max_buy_value / market.price;
        let adjusted_shares = shares_to_buy * lot_size_multiplier;
        let buy_amount = clamp_val(adjusted_shares, 1, 1_000_000_000);
        orders.submit_limit_sell(market.price, buy_amount);
    }
}