let initialized = false;
let lot_size_pct = 0;
let stop_loss_ticks = 0;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size_pct = rng.rand_int(30, 50);
        stop_loss_ticks = rng.rand_int(1, 3);
        panic_threshold = -rng.rand_int(1000, 5000);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.stock > 0 {
        let stop_price = account.avg_cost - stop_loss_ticks;
        if market.price <= stop_price || account.unrealized_pnl < panic_threshold {
            orders.submit_market_sell(account.stock);
            return;
        }
    } else {
        if market.price > market.high_20 {
            let buy_cash = account.cash * lot_size_pct / 100;
            let buy_amount = buy_cash / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
    }
}