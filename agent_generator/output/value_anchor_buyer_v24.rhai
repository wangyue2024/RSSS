let initialized = false;
let my_fair_value = 0;
let active = false;

fn on_tick() {
    if !initialized {
        my_fair_value = rng.rand_int(95_000_000, 105_000_000);
        initialized = true;
    }

    if !market.trading_enabled { return; }

    active = market.tick < market.total_ticks * 20 / 100;
    if !active { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let price = market.price;
    if price >= my_fair_value { return; }

    let cash = account.cash;
    if cash <= 0 { return; }

    let buy_amount;
    let level_95 = my_fair_value * 95 / 100;
    let level_90 = my_fair_value * 90 / 100;

    if price < level_90 {
        let max_by_cash = cash / price;
        buy_amount = max_by_cash * 10 / 100;
        if buy_amount < 1 { buy_amount = 1; }
    } else if price < level_95 {
        let max_by_cash = cash / price;
        buy_amount = max_by_cash * 2 / 100;
        if buy_amount < 1 { buy_amount = 1; }
    } else {
        return;
    }

    orders.submit_limit_buy(price, buy_amount);
}