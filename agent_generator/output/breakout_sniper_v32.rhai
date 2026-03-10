let initialized = false;
let stop_loss_ticks = 0;
let panic_threshold = 0;
let last_evaluation_tick = -50;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_ticks = rng.rand_int(3, 7);
        panic_threshold = rng.rand_int(-25000, -5000);
    }

    if !market.trading_enabled { return; }

    let tick = market.tick;
    let morning_active = tick < market.total_ticks / 5;
    let lazy_eval = (tick - last_evaluation_tick) >= 50;

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

    if !morning_active { return; }
    if !lazy_eval { return; }
    last_evaluation_tick = tick;

    let stop_price = account.avg_cost - stop_loss_ticks;
    if account.stock > 0 && stop_price > 0 && market.price < stop_price {
        orders.submit_market_sell(account.stock);
        return;
    }

    if account.stock > 0 { return; }

    if market.price > market.high_20 {
        let buy_cash = account.cash * 60 / 100;
        let buy_amount = buy_cash / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    }
}