let initialized = false;
let spread_micros = 0;
let order_amount = 0;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(5000, 20000);
        order_amount = rng.rand_int(100, 500);
        panic_threshold = -rng.rand_int(10000, 50000);
    }

    if !market.trading_enabled { return; }

    let pnl = account.unrealized_pnl;
    if pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid = market.price;
    let buy_price = mid - spread_micros;
    let sell_price = mid + spread_micros;

    if account.cash >= buy_price * order_amount {
        orders.submit_limit_buy(buy_price, order_amount);
    }
    if account.stock >= order_amount {
        orders.submit_limit_sell(sell_price, order_amount);
    }
}