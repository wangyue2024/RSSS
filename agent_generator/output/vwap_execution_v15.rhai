let total_target = 10_000;
let base_lot_size = 100;
let current_lot_size = 100;
let last_trade_profitable = true;
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(80, 120);
        current_lot_size = base_lot_size;
    }

    if !market.trading_enabled { return; }

    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let i = 0;
        while i < fill_cnt {
            let fill_side = my_orders.fill_side(i);
            if fill_side == 0 {
                if account.avg_cost > 0 && market.price < account.avg_cost {
                    last_trade_profitable = false;
                } else {
                    last_trade_profitable = true;
                }
            }
            i += 1;
        }
    }

    if !last_trade_profitable {
        current_lot_size = current_lot_size * 2;
    } else {
        current_lot_size = base_lot_size;
    }

    let volume_factor = 100;
    if market.volume > 0 {
        let recent_vol = 0;
        let lookback = 10;
        let hist_len = market.history_len();
        if hist_len < lookback { lookback = hist_len; }
        let j = 0;
        while j < lookback {
            recent_vol += market.history_volume(j);
            j += 1;
        }
        if lookback > 0 {
            let avg_recent_vol = recent_vol / lookback;
            if avg_recent_vol > 0 {
                volume_factor = market.volume * 100 / avg_recent_vol;
            }
        }
    }

    volume_factor = clamp_val(volume_factor, 50, 200);
    let dynamic_lot = current_lot_size * volume_factor / 100;

    let pending_cnt = my_orders.pending_count();
    let k = 0;
    while k < pending_cnt {
        let oid = my_orders.pending_id(k);
        orders.submit_cancel(oid);
        k += 1;
    }

    if account.stock < total_target {
        let remaining = total_target - account.stock;
        let order_size = dynamic_lot;
        if order_size > remaining { order_size = remaining; }
        if order_size > 0 {
            orders.submit_limit_buy(market.bid_price_0, order_size);
        }
    }
}