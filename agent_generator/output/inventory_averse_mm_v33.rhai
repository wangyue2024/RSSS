let initialized = false;
let panic_threshold = 0;
let morning_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(1000, 10000);
        morning_ticks = market.total_ticks * 2 / 10;
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.tick >= morning_ticks { return; }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let inv = account.stock;
    let base_spread = 100;
    let buy_offset = base_spread;
    let sell_offset = base_spread;

    if inv > 1000 {
        buy_offset = base_spread * 3 / 2;
        sell_offset = base_spread / 2;
    } else if inv <= 0 {
        buy_offset = base_spread / 2;
        sell_offset = base_spread * 3 / 2;
    }

    let mid = market.price;
    let buy_price = mid - buy_offset;
    let sell_price = mid + sell_offset;

    if buy_price > 0 && account.cash >= buy_price * 100 / 1_000_000 {
        orders.submit_limit_buy(buy_price, 100);
    }

    if sell_price > 0 && account.stock >= 100 && sell_price > account.avg_cost {
        orders.submit_limit_sell(sell_price, 100);
    }
}