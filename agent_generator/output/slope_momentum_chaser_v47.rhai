let initialized = false;
let price_buffer = [];
let slope_threshold_positive = 1000;
let slope_threshold_negative = -500;
let panic_slope_threshold = -2000;
let lookback_ticks = 20;
let delay_ticks = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
        slope_threshold_positive = rng.rand_int(800, 1500);
        slope_threshold_negative = rng.rand_int(-800, -200);
        panic_slope_threshold = rng.rand_int(-3000, -1000);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    price_buffer.push(market.price);
    if price_buffer.len() > lookback_ticks + delay_ticks {
        price_buffer.remove(0);
    }

    if price_buffer.len() < lookback_ticks + delay_ticks {
        return;
    }

    let delayed_prices = [];
    let start_idx = price_buffer.len() - delay_ticks - lookback_ticks;
    let end_idx = price_buffer.len() - delay_ticks;
    let idx = start_idx;
    while idx < end_idx {
        delayed_prices.push(price_buffer[idx]);
        idx += 1;
    }

    let current_slope = arr_slope(delayed_prices);
    let prev_slope = 0;

    if price_buffer.len() >= lookback_ticks + delay_ticks + 5 {
        let prev_delayed_prices = [];
        let prev_start = start_idx - 5;
        let prev_end = start_idx;
        let prev_idx = prev_start;
        while prev_idx < prev_end {
            prev_delayed_prices.push(price_buffer[prev_idx]);
            prev_idx += 1;
        }
        prev_slope = arr_slope(prev_delayed_prices);
    }

    let acceleration = current_slope - prev_slope;
    let aggressive_buy = false;

    if current_slope > slope_threshold_positive && acceleration > 0 {
        aggressive_buy = true;
    }

    if aggressive_buy {
        let cash_available = account.cash;
        let max_shares = cash_available / market.price;
        if max_shares > 0 {
            let buy_amount = max_shares * 3 / 10;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
    } else if current_slope < panic_slope_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
    } else if current_slope < slope_threshold_negative {
        if account.stock > 0 {
            let sell_amount = account.stock / 2;
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
            }
        }
    }
}