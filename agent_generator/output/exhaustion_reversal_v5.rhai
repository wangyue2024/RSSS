let initialized = false;
let my_lot_size = 0;
let my_volume_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let five_percent_cap = account.total_equity * 5 / 100;
        if five_percent_cap == 0 {
            five_percent_cap = 1_000_000;
        }
        let max_shares = five_percent_cap / market.price;
        if max_shares < 1 {
            max_shares = 1;
        }
        my_lot_size = rng.rand_int(1, max_shares);
        my_volume_threshold = rng.rand_int(1, 10);
    }

    if !market.trading_enabled {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.std_dev > (market.price * 10 / 100) {
        return;
    }

    let volume_low = false;
    if market.history_len() >= 5 {
        let recent_volumes = [];
        let idx = 0;
        while idx < 5 {
            recent_volumes.push(market.history_volume(market.history_len() - 1 - idx));
            idx += 1;
        }
        let avg_vol = arr_mean(recent_volumes);
        if avg_vol > 0 && market.volume < (avg_vol * my_volume_threshold / 100) {
            volume_low = true;
        }
    }

    let price_above_ma = market.price > market.ma_60;

    if volume_low && price_above_ma {
        let raw_price = market.price;
        let rounded_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
        if account.stock >= my_lot_size {
            orders.submit_limit_sell(rounded_price, my_lot_size);
        } else {
            let buy_price = rounded_price - 1_000_000;
            if buy_price > 0 {
                orders.submit_limit_buy(buy_price, my_lot_size);
            }
        }
    }
}