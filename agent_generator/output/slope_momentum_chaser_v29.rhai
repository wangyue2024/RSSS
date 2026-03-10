let initialized = false;
let lookback = 20;
let slope_threshold = 3000;
let panic_threshold = -1500;
let max_position_pct = 50;
let base_lot_size = 0;
let prev_slope = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(15_000_000, 25_000_000);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.history_len() < lookback {
        return;
    }

    let price_history = [];
    let j = 0;
    while j < lookback {
        price_history.push(market.history_price(j));
        j += 1;
    }

    let current_slope = arr_slope(price_history);

    let buy_power = account.cash * max_position_pct / 100;
    let sell_power = account.stock * max_position_pct / 100;

    if current_slope > slope_threshold && current_slope > prev_slope {
        let agg_factor = 100 + (current_slope - slope_threshold) * 10 / 1000;
        let buy_amount = base_lot_size * agg_factor / 100;
        buy_amount = clamp_val(buy_amount, 100, buy_power / market.price);
        if buy_amount > 0 {
            orders.submit_limit_buy(market.price, buy_amount);
        }
    }

    if current_slope < panic_threshold && account.stock > 0 {
        let sell_amount = base_lot_size;
        sell_amount = clamp_val(sell_amount, 100, sell_power);
        if sell_amount > 0 {
            orders.submit_market_sell(sell_amount);
        }
    }

    prev_slope = current_slope;
}