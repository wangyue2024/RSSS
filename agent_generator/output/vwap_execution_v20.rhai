let initialized = false;
let target_shares = 1000000;
let bought_shares = 0;
let base_slice = 10000;
let panic_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled {
        return;
    }

    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        let fill_side = my_orders.fill_side(i);
        let fill_amount = my_orders.fill_amount(i);
        if fill_side == 0 {
            bought_shares += fill_amount;
        }
        i += 1;
    }

    if bought_shares >= target_shares {
        return;
    }

    let remaining = target_shares - bought_shares;
    if remaining <= 0 {
        return;
    }

    let history_len = market.history_len();
    if history_len >= 5 {
        let current_price = market.price;
        let price_5_ago = market.history_price(history_len - 5);
        if price_5_ago != 0 {
            let change_bps = (current_price - price_5_ago) * 10000 / price_5_ago;
            if change_bps > 200 {
                panic_triggered = true;
            }
        }
    }

    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }

    if panic_triggered {
        orders.submit_market_buy(remaining);
        return;
    }

    let vol_lookback = 20;
    let volumes = [];
    let available = market.history_len();
    let start = 0;
    if available > vol_lookback {
        start = available - vol_lookback;
    }
    for k in start..available {
        volumes.push(market.history_volume(k));
    }

    let avg_vol = arr_mean(volumes);
    if avg_vol == 0 {
        avg_vol = 1;
    }

    let slice = base_slice * market.volume / avg_vol;
    if slice < 1 {
        slice = 1;
    }
    if slice > remaining {
        slice = remaining;
    }

    if slice > 0 {
        let vwap_price = market.vwap;
        if vwap_price == 0 {
            vwap_price = market.price;
        }
        let limit_price = vwap_price * 999 / 1000;
        if limit_price < 1 {
            limit_price = 1;
        }
        orders.submit_limit_buy(limit_price, slice);
    }
}