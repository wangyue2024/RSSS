let initialized = false;
let lot_size = 0;
let prev_ma_diff = 0;
let fomo_triggered = false;
let prev_price = 0;
let prev_tick = 0;

fn on_tick() {
    if !initialized {
        let total_cap = account.total_equity;
        let five_percent_cap = total_cap * 5 / 100;
        let max_shares = five_percent_cap / market.price;
        if max_shares == 0 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
        prev_ma_diff = market.ma_5 - market.ma_20;
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_tick = market.tick;
    if prev_price != 0 && (current_tick - prev_tick) <= 10 {
        let change_percent = (market.price - prev_price) * 100 / prev_price;
        if change_percent > 2 && !fomo_triggered {
            let threshold_std_dev = market.price * 5 / 100;
            if market.std_dev <= threshold_std_dev {
                orders.submit_market_buy(lot_size);
                fomo_triggered = true;
            }
        } else {
            fomo_triggered = false;
        }
    }

    prev_price = market.price;
    prev_tick = current_tick;

    if fomo_triggered { return; }

    let threshold_std_dev = market.price * 5 / 100;
    if market.std_dev > threshold_std_dev { return; }

    let current_ma_diff = market.ma_5 - market.ma_20;

    if prev_ma_diff <= 0 && current_ma_diff > 0 {
        orders.submit_market_buy(lot_size);
    }

    if prev_ma_diff >= 0 && current_ma_diff < 0 && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }

    prev_ma_diff = current_ma_diff;
}