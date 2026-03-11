let initialized = false;
let panic_threshold = 0;
let base_size = 100;
let range_offset_pct = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(10_000, 50_000);
        base_size = rng.rand_int(80, 120);
        range_offset_pct = rng.rand_int(3, 7);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    let low_20 = market.low_20;
    let high_20 = market.high_20;
    if low_20 == 0 || high_20 == 0 { return; }

    let spread = high_20 - low_20;
    let offset = spread * range_offset_pct / 100;

    let buy_price = low_20 + offset;
    let sell_price = high_20 - offset;

    if buy_price >= sell_price {
        buy_price = low_20;
        sell_price = high_20;
    }

    let spread_ratio = spread * 100 / low_20;
    let size_multiplier = 10000 / (spread_ratio + 100);
    let adjusted_size = base_size * size_multiplier / 100;

    let max_buy_shares = account.cash / buy_price;
    let buy_shares = adjusted_size;
    if buy_shares > max_buy_shares { buy_shares = max_buy_shares; }

    let sell_shares = adjusted_size;
    if sell_shares > account.stock { sell_shares = account.stock; }

    if buy_shares > 0 {
        orders.submit_limit_buy(buy_price, buy_shares);
    }
    if sell_shares > 0 {
        orders.submit_limit_sell(sell_price, sell_shares);
    }
}