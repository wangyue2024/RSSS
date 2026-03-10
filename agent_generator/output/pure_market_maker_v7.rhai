let initialized = false;
let spread_micros = 0;
let order_size = 0;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(1000, 5000);
        order_size = rng.rand_int(10, 50);
        panic_threshold = -rng.rand_int(50000, 200000);
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;
    let total_ticks = market.total_ticks;
    if current_tick >= total_ticks / 5 {
        return;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    let current_price = market.price;
    let buy_price = current_price - spread_micros;
    let sell_price = current_price + spread_micros;

    if account.cash >= buy_price * order_size {
        orders.submit_limit_buy(buy_price, order_size);
    }
    if account.stock >= order_size {
        orders.submit_limit_sell(sell_price, order_size);
    }
}