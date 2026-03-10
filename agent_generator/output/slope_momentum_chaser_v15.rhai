let panic_threshold = 0;
let price_history = [];
let last_action_tick = 0;
let initialized = false;

fn round_to_dollar(price_micros) {
    ((price_micros + 500_000) / 1_000_000) * 1_000_000
}

fn get_slope(arr) {
    if arr.len() < 2 { return 0; }
    arr_slope(arr)
}

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(5_000, 50_000);
        last_action_tick = market.tick;
    }

    if !market.trading_enabled { return; }

    price_history.push(market.price);
    if price_history.len() > 100 {
        price_history.remove(0);
    }

    let delayed_tick = market.tick - 5;
    if delayed_tick < 0 || market.tick <= last_action_tick { return; }

    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        last_action_tick = market.tick;
        return;
    }

    if price_history.len() < 20 { return; }

    let recent_prices = [];
    let start_idx = price_history.len() - 20;
    let j = start_idx;
    while j < price_history.len() {
        recent_prices.push(price_history[j]);
        j += 1;
    }

    let slope = get_slope(recent_prices);

    if slope > 50_000 && account.cash > 10_000_000 {
        let buy_price = round_to_dollar(market.price);
        let max_shares = account.cash / buy_price;
        if max_shares > 0 {
            let shares = max_shares;
            if shares > 100 { shares = 100; }
            orders.submit_limit_buy(buy_price, shares);
            last_action_tick = market.tick;
        }
    } else if slope < -20_000 && account.stock > 0 {
        let sell_price = round_to_dollar(market.price);
        orders.submit_limit_sell(sell_price, account.stock);
        last_action_tick = market.tick;
    }
}