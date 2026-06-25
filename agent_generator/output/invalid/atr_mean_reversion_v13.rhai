let initialized = false;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(1_000_000, 5_000_000);
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

    let deviation = market.price - market.ma_20;
    let abs_dev = abs_val(deviation);
    let atr_threshold = market.atr_14 * 150 / 100;

    if abs_dev > atr_threshold {
        if deviation > 0 {
            if account.stock > 0 && market.price > account.avg_cost {
                let sell_price = ((market.price + 500_000) / 1_000_000) * 1_000_000;
                let sell_amount = if account.stock > 100 { 100 } else { account.stock };
                orders.submit_limit_sell(sell_price, sell_amount);
            }
        } else {
            let buy_price = ((market.price + 500_000) / 1_000_000) * 1_000_000;
            let max_buy = account.cash / market.price;
            let buy_amount = if max_buy > 100 { 100 } else { max_buy };
            if buy_amount > 0 {
                orders.submit_limit_buy(buy_price, buy_amount);
            }
        }
    }
}