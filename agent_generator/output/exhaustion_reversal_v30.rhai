let initialized = false;
let active_phase_ticks = 0;
let exhaust_signal_active = false;
let last_action_tick = -1000;
let cooldown_ticks = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
        active_phase_ticks = market.total_ticks / 5;
    }

    if !market.trading_enabled { return; }

    if market.tick >= active_phase_ticks { return; }

    let current_tick = market.tick;
    let price = market.price;
    let volume = market.volume;

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if current_tick - last_action_tick < cooldown_ticks { return; }

    let avg_volume = 0;
    let lookback = 10.min(market.history_len());
    if lookback > 0 {
        let sum = 0;
        let j = 0;
        while j < lookback {
            sum += market.history_volume(j);
            j += 1;
        }
        avg_volume = sum / lookback;
    }

    let volume_drop_threshold = avg_volume * 5 / 100;
    let price_above_ma = price > market.ma_60;

    if price_above_ma && volume < volume_drop_threshold && volume > 0 {
        exhaust_signal_active = true;
    } else {
        exhaust_signal_active = false;
    }

    if exhaust_signal_active {
        let sell_amount = 1000;
        if account.stock >= sell_amount {
            let target_price = market.bid_price_0 - 1;
            let limit_price = if target_price > 0 { target_price } else { price * 999 / 1000 };
            orders.submit_limit_sell(limit_price, sell_amount);
            last_action_tick = current_tick;
        }
    } else {
        if account.cash > 1000000 && market.bid_price_0 > 0 {
            let buy_amount = 500;
            let limit_price = market.bid_price_0 + 1;
            orders.submit_limit_buy(limit_price, buy_amount);
        }
    }
}