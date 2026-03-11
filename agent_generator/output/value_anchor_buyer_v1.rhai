let fair_value = 0;
let panic_threshold = 0;
let initialized = false;

fn on_tick() {
    if !initialized {
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        panic_threshold = -rng.rand_int(100_000, 1_000_000);
        initialized = true;
    }

    if !market.trading_enabled { return; }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    if market.tick % 50 != 0 { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let price = market.price;
    let aggressive_thresh = fair_value * 90 / 100;
    let moderate_thresh = fair_value * 95 / 100;

    if price < aggressive_thresh && account.cash > 0 {
        let cash_to_use = account.cash * 50 / 100;
        let buy_amount = cash_to_use / price;
        if buy_amount > 0 {
            orders.submit_limit_buy(price, buy_amount);
        }
    } else if price < moderate_thresh && account.cash > 0 {
        let cash_to_use = account.cash * 20 / 100;
        let buy_amount = cash_to_use / price;
        if buy_amount > 0 {
            orders.submit_limit_buy(price, buy_amount);
        }
    }
}