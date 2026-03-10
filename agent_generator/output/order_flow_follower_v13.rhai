let initialized = false;
let lot_size = 0;
let threshold_std_dev = 500_000;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_cap = account.total_equity * 5 / 100;
        lot_size = rng.rand_int(1, max_cap);
        if lot_size < 1 { lot_size = 1; }
    }

    if !market.trading_enabled { return; }

    if market.tick >= market.total_ticks / 5 {
        return;
    }

    if market.tick % 50 != 0 {
        return;
    }

    if market.std_dev > threshold_std_dev {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.buy_volume > 3 * market.sell_volume {
        let ask_price = if market.ask_price_0 != 0 { market.ask_price_0 } else { market.price };
        let max_by_cash = account.cash / ask_price;
        let buy_amount = if max_by_cash < lot_size { max_by_cash } else { lot_size };
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    }
}