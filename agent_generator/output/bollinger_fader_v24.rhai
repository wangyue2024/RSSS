let initialized = false;
let trade_amount = 100;
let fomo_window = 5;
let fomo_threshold = 20000;

fn on_tick() {
    if !initialized {
        initialized = true;
        if rng.rand_bool(50) {
            trade_amount = 50;
        }
    }

    if !market.trading_enabled { return; }

    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.history_len() >= fomo_window {
        let past_price = market.history_price(fomo_window - 1);
        if past_price > 0 {
            let price_change = (market.price - past_price) * 10000 / past_price;
            if price_change > fomo_threshold {
                orders.submit_market_buy(trade_amount);
                return;
            }
        }
    }

    if market.ma_20 > 0 && market.std_dev > 0 {
        let lower_band = market.ma_20 - 2 * market.std_dev;
        let upper_band = market.ma_20 + 2 * market.std_dev;

        if account.cash >= lower_band * trade_amount {
            orders.submit_limit_buy(lower_band, trade_amount);
        }
        if account.stock >= trade_amount {
            orders.submit_limit_sell(upper_band, trade_amount);
        }
    }
}