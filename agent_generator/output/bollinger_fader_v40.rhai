let initialized = false;
let lot_size = 0;
let last_fomo_check = 0;
let price_history = [];

fn on_tick() {
    if !market.trading_enabled {
        return;
    }

    if !initialized {
        initialized = true;
        let five_percent_cap = account.total_equity * 5 / 100;
        lot_size = rng.rand_int(1, five_percent_cap);
        if lot_size < 1 {
            lot_size = 1;
        }
    }

    let current_price = market.price;
    price_history.push(current_price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }

    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let two_percent_move = current_price * 2 / 100;
    if price_history.len() >= 5 {
        let idx = price_history.len() - 1;
        let price_5_ago = price_history[idx - 4];
        let jump = abs_val(current_price - price_5_ago);
        if jump > two_percent_move {
            let buy_amount = clamp_val(lot_size, 1, account.cash / current_price);
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }

    let two_percent_price = current_price * 2 / 100;
    if market.std_dev > two_percent_price {
        return;
    }

    if market.ma_20 == 0 || market.std_dev == 0 {
        return;
    }

    let lower_band = market.ma_20 - 2 * market.std_dev;
    let upper_band = market.ma_20 + 2 * market.std_dev;

    if lower_band > 0 {
        let buy_price = lower_band + 1;
        let max_buy_amount = account.cash / buy_price;
        let buy_amount = clamp_val(lot_size, 1, max_buy_amount);
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }

    if account.stock > 0 {
        let sell_price = upper_band - 1;
        let sell_amount = clamp_val(lot_size, 1, account.stock);
        if sell_price > 0 && sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}