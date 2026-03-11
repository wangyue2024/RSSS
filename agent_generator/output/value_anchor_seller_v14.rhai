let initialized = false;
let fair_value_base = 0;
let panic_threshold = 0;
let fair_value_105 = 0;
let fair_value_110 = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value_base = 100_000_000 + rng.rand_int(-5_000_000, 5_000_000);
        panic_threshold = rng.rand_int(-500_000, -100_000);
        fair_value_105 = fair_value_base * 105 / 100;
        fair_value_110 = fair_value_base * 110 / 100;
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    if market.price <= account.avg_cost {
        return;
    }

    let sell_amount = 0;
    if market.price > fair_value_110 && account.stock > 0 {
        sell_amount = account.stock * 50 / 100;
    } else if market.price > fair_value_105 && account.stock > 0 {
        sell_amount = account.stock * 10 / 100;
    }

    if sell_amount > 0 {
        orders.submit_limit_sell(market.bid_price_0, sell_amount);
    }
}