let initialized = false;
let lookback = 10;
let panic_threshold = 0;
let prev_slope = 0;
let prev_price = 0;
let momentum_window = 5;
let momentum_history = [];
let buy_aggression = 0;
let stop_loss_active = false;
let stop_loss_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(10_000, 100_000);
        buy_aggression = rng.rand_int(30, 70);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        stop_loss_active = false;
        return;
    }

    if market.history_len() < lookback {
        return;
    }

    let price_arr = [];
    let j = 0;
    while j < lookback {
        price_arr.push(market.history_price(lookback - 1 - j));
        j += 1;
    }
    let current_slope = arr_slope(price_arr);

    momentum_history.push(current_slope);
    if momentum_history.len() > momentum_window {
        momentum_history.remove(0);
    }

    let slope_accel = 0;
    if momentum_history.len() >= 2 {
        slope_accel = current_slope - momentum_history[momentum_history.len() - 2];
    }

    let should_panic_sell = current_slope < 0 && prev_slope > 0 && account.stock > 0;
    let should_aggressive_buy = current_slope > 0 && slope_accel > 0 && current_slope > prev_slope;

    if should_panic_sell {
        orders.submit_market_sell(account.stock);
        stop_loss_active = false;
    } else if should_aggressive_buy && account.cash > 1_000_000 {
        let buy_power = account.cash * buy_aggression / 100;
        let approx_shares = buy_power / market.price;
        if approx_shares > 0 {
            let buy_price = market.ask_price_0 + 1;
            orders.submit_limit_buy(buy_price, approx_shares);
            stop_loss_active = true;
            stop_loss_price = market.price * 98 / 100;
        }
    } else if stop_loss_active && market.price < stop_loss_price && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        stop_loss_active = false;
    }

    prev_slope = current_slope;
    prev_price = market.price;
}