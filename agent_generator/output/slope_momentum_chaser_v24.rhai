let initialized = false;
let prev_slope = 0;
let slope_window = 20;
let panic_sell_threshold = 0;
let last_buy_tick = -1000;
let buy_hold_ticks = 5;
let max_position = 1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_sell_threshold = -rng.rand_int(10_000, 50_000);
    }

    if !market.trading_enabled { return; }

    let pcount = my_orders.pending_count();
    let i = 0;
    while i < pcount {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < panic_sell_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    if market.history_len() < slope_window { return; }

    let price_arr = [];
    let j = 0;
    while j < slope_window {
        price_arr.push(market.history_price(market.history_len() - slope_window + j));
        j += 1;
    }
    let cur_slope = arr_slope(price_arr);

    let momentum = cur_slope > 500 && cur_slope > prev_slope;
    let panic = cur_slope < -1000;
    let can_buy = market.tick - last_buy_tick > buy_hold_ticks && account.stock < max_position;

    if panic && account.stock > 0 {
        let sell_amt = account.stock * 30 / 100;
        if sell_amt > 0 {
            orders.submit_market_sell(sell_amt);
        }
    } else if momentum && can_buy && market.ask_price_0 > 0 {
        let cash_amt = account.cash * 15 / 100;
        let buy_amt = cash_amt / market.ask_price_0;
        if buy_amt > 0 {
            orders.submit_limit_buy(market.ask_price_0, buy_amt);
            last_buy_tick = market.tick;
        }
    }

    prev_slope = cur_slope;
}