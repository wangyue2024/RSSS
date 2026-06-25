let initialized = false;
let lot_size_percent = 0;
let threshold_pct = 0;
let fomo_window = 5;
let fomo_threshold_pct = 200;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size_percent = rng.rand_int(40, 50);
        threshold_pct = rng.rand_int(50, 150);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.history_len() >= fomo_window {
        let price_now = market.price;
        let price_past = market.history_price(fomo_window - 1);
        if price_past != 0 {
            let change = (price_now - price_past) * 10000 / price_past;
            if change > fomo_threshold_pct {
                let buy_amount = (account.cash * lot_size_percent) / 100;
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount / market.price);
                }
                return;
            }
        }
    }

    let vwap = market.vwap;
    let price = market.price;

    if vwap > 0 && price > 0 {
        let diff_pct = (vwap - price) * 10000 / vwap;

        if account.stock == 0 && diff_pct > threshold_pct {
            let raw_price = price;
            let rounded_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
            let buy_cash = (account.cash * lot_size_percent) / 100;
            let buy_shares = buy_cash / rounded_price;
            if buy_shares > 0 {
                orders.submit_limit_buy(rounded_price, buy_shares);
            }
        }

        if account.stock > 0 && price >= vwap {
            let sell_price = ((price + 500_000) / 1_000_000) * 1_000_000;
            orders.submit_limit_sell(sell_price, account.stock);
        }
    }
}