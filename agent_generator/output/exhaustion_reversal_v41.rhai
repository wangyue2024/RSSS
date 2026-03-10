let initialized = false;
let percent_cap = 0;
let std_thresh = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        percent_cap = rng.rand_int(1, 5);
        std_thresh = 300_000;
    }

    if !market.trading_enabled {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.std_dev > std_thresh {
        return;
    }

    let lot_value = account.total_equity * percent_cap / 100;
    let lot_size = lot_value / market.price;
    if lot_size <= 0 {
        return;
    }

    let vol_exhaust = false;
    if market.history_len() >= 5 {
        let vol_sum = 0;
        let idx = 0;
        while idx < 5 {
            vol_sum += market.history_volume(idx);
            idx += 1;
        }
        let avg_vol = vol_sum / 5;
        if market.volume < avg_vol / 10 {
            vol_exhaust = true;
        }
    }

    if vol_exhaust && market.price > market.ma_60 && account.stock >= lot_size {
        let raw_price = market.price;
        let round_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
        orders.submit_limit_sell(round_price, lot_size);
    }
}