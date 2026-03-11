let initialized = false;
let risk_mode = 0;
let base_lot_pct = 0;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_mode = rng.rand_int(0, 1);
        if risk_mode == 0 {
            base_lot_pct = rng.rand_int(1, 5);
        } else {
            base_lot_pct = rng.rand_int(25, 50);
        }
        panic_threshold = -rng.rand_int(500, 5000);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if risk_mode == 0 && market.std_dev > 5000000 {
        return;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let spread = market.high_20 - market.low_20;
    let range_adjusted_pct = base_lot_pct;
    if spread < 1000000 && spread > 0 {
        range_adjusted_pct = range_adjusted_pct * 1000000 / spread;
        if range_adjusted_pct > 100 { range_adjusted_pct = 100; }
    }

    let cash_to_use = account.cash * range_adjusted_pct / 100;
    if cash_to_use <= 0 { return; }

    let buy_price = market.low_20 + spread * 5 / 100;
    let sell_price = market.high_20 - spread * 5 / 100;

    let buy_amount = cash_to_use / buy_price;
    if buy_amount > 0 {
        orders.submit_limit_buy(buy_price, buy_amount);
    }

    if account.stock > 0 {
        let sell_amount = account.stock;
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}