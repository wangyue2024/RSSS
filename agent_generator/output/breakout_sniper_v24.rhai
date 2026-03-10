let initialized = false;
let panic_threshold = 0;
let stop_loss_ticks = 0;
let aggressive_buy_pct = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(100000, 500000);
        stop_loss_ticks = rng.rand_int(5, 20);
        aggressive_buy_pct = rng.rand_int(80, 100);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    if account.stock == 0 {
        if market.price > market.high_20 {
            let buy_val = account.cash * aggressive_buy_pct / 100;
            let buy_amount = buy_val / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
    } else {
        let stop_price = account.avg_cost - stop_loss_ticks;
        orders.submit_limit_sell(stop_price, account.stock);
    }
}