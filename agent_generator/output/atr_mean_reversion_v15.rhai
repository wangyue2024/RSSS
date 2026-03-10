let initialized = false;
let panic_threshold = 0;
let order_size = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(10_000, 50_000);
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

    let deviation = market.price - market.ma_20;
    let atr_scaled = market.atr_14 * 15 / 10;

    if deviation > atr_scaled && account.cash >= market.price * order_size {
        let target_price_raw = market.ma_20 + atr_scaled * 2 / 3;
        let rounded_price = ((target_price_raw + 500_000) / 1_000_000) * 1_000_000;
        orders.submit_limit_buy(rounded_price, order_size);
    } else if deviation < -atr_scaled && account.stock >= order_size {
        let target_price_raw = market.ma_20 - atr_scaled * 2 / 3;
        let rounded_price = ((target_price_raw + 500_000) / 1_000_000) * 1_000_000;
        orders.submit_limit_sell(rounded_price, order_size);
    }
}