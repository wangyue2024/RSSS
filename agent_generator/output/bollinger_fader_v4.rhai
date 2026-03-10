let initialized = false;
let lot_size_percent = 0;

fn round_to_dollar(price) {
    let remainder = price % 1_000_000;
    if remainder >= 500_000 {
        price - remainder + 1_000_000
    } else {
        price - remainder
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size_percent = rng.rand_int(40, 50);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.tick % 50 == 0 {
        let upper_band = market.ma_20 + 2 * market.std_dev;
        let lower_band = market.ma_20 - 2 * market.std_dev;

        let buy_price = round_to_dollar(lower_band);
        let sell_price = round_to_dollar(upper_band);

        let cash_to_use = account.cash * lot_size_percent / 100;
        let buy_amount = cash_to_use / buy_price;

        let stock_to_sell = account.stock * lot_size_percent / 100;

        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }

        if stock_to_sell > 0 {
            orders.submit_limit_sell(sell_price, stock_to_sell);
        }
    }
}