let initialized = false;
let lookback = 20;
let fomo_lookback = 5;
let trade_freq = 50;
let max_risk_pct = 5;
let volatility_threshold_pct = 2;
let panic_slope_threshold = -500;
let aggressive_slope_threshold = 3000;
let lot_size_pct = 0;
let prev_slope = 0;
let prev_price = 0;
let tick_counter = 0;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        lot_size_pct = rng.rand_int(1, max_risk_pct);
        prev_price = market.price;
    }

    let current_tick = market.tick;
    tick_counter += 1;

    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let fomo_price_jump = false;
    if market.history_len() >= fomo_lookback {
        let price_now = market.price;
        let price_past = market.history_price(fomo_lookback - 1);
        let jump_pct = (price_now - price_past) * 10000 / price_past;
        if jump_pct > 200 {
            fomo_price_jump = true;
        }
    }

    let volatility_too_high = false;
    let vol_pct = market.std_dev * 10000 / market.price;
    if vol_pct > volatility_threshold_pct * 100 {
        volatility_too_high = true;
    }

    if fomo_price_jump && !volatility_too_high {
        let cash_to_use = account.total_equity * lot_size_pct / 100;
        let buy_amount = cash_to_use / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        return;
    }

    if tick_counter % trade_freq != 0 {
        return;
    }

    if volatility_too_high {
        return;
    }

    if market.history_len() < lookback {
        return;
    }

    let price_arr = [];
    let idx = 0;
    while idx < lookback {
        price_arr.push(market.history_price(idx));
        idx += 1;
    }
    let current_slope = arr_slope(price_arr);

    if current_slope < panic_slope_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    } else if current_slope > aggressive_slope_threshold && current_slope > prev_slope {
        let cash_to_use = account.total_equity * lot_size_pct / 100;
        let buy_amount = cash_to_use / market.price;
        if buy_amount > 0 && account.cash >= market.price * buy_amount {
            orders.submit_limit_buy(market.price, buy_amount);
        }
    }

    prev_slope = current_slope;
    prev_price = market.price;
}