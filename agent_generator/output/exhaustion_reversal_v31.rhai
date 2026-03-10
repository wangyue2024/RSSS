let initialized = false;
let last_decision_tick = -100;
let round_bias = 0;
let price_window = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];

fn on_tick() {
    if !initialized {
        initialized = true;
        round_bias = rng.rand_int(0, 10);
    }

    if !market.trading_enabled {
        return;
    }

    let curr_price = market.price;
    price_window.remove(0);
    price_window.push(curr_price);

    let tick = market.tick;
    let check_fomo = price_window.len() >= 10;
    if check_fomo {
        let oldest_price = price_window[0];
        if oldest_price != 0 {
            let price_change_percent = (curr_price - oldest_price) * 100 / oldest_price;
            if price_change_percent > 2 || price_change_percent < -2 {
                orders.submit_market_buy(100);
                return;
            }
        }
    }

    if (tick - last_decision_tick) < 50 {
        return;
    }
    last_decision_tick = tick;

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let above_ma = curr_price > market.ma_60;
    let volume_drop = false;

    if market.history_len() >= 20 {
        let recent_vols = [];
        let j = 0;
        while j < 20 {
            recent_vols.push(market.history_volume(j));
            j += 1;
        }
        let avg_vol = arr_mean(recent_vols);
        if avg_vol > 0 {
            let vol_ratio = market.volume * 100 / avg_vol;
            if vol_ratio < 10 {
                volume_drop = true;
            }
        }
    }

    if above_ma && volume_drop && account.stock > 0 {
        let raw_price = curr_price;
        let rounded = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
        let adj_price = rounded + round_bias * 100_000;
        let sell_qty = account.stock / 10;
        if sell_qty > 0 {
            orders.submit_limit_sell(adj_price, sell_qty);
        }
    }
}