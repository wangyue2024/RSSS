let initialized = false;
let prev_slope = 0;
let lookback = 10;
let buy_slope_threshold = 20000;
let panic_slope_threshold = -5000;

fn on_tick() {
    if !initialized {
        initialized = true;
        lookback = rng.rand_int(8, 15);
        buy_slope_threshold = rng.rand_int(15000, 30000);
        panic_slope_threshold = rng.rand_int(-10000, -2000);
    }

    if !market.trading_enabled { return; }
    if market.tick >= market.total_ticks * 20 / 100 { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let hist_len = market.history_len();
    if hist_len < lookback { return; }

    let price_hist = [];
    let idx = 0;
    while idx < lookback {
        price_hist.push(market.history_price(idx));
        idx += 1;
    }
    let current_slope = arr_slope(price_hist);

    if account.stock > 0 && market.price > account.avg_cost {
        if current_slope < panic_slope_threshold {
            orders.submit_market_sell(account.stock);
        } else if current_slope > 0 && current_slope < prev_slope {
            let sell_amt = account.stock * 30 / 100;
            if sell_amt > 0 {
                orders.submit_market_sell(sell_amt);
            }
        }
    }

    if current_slope > buy_slope_threshold && current_slope > prev_slope {
        let buy_cash = account.cash * 40 / 100;
        let buy_amt = buy_cash / market.price;
        if buy_amt > 0 {
            orders.submit_market_buy(buy_amt);
        }
    }

    prev_slope = current_slope;
}