let total_target = 0;
let remaining = 0;
let initialized = false;
let price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        total_target = rng.rand_int(5000, 20000);
        remaining = total_target;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let fill_cnt = my_orders.fill_count();
    i = 0;
    while i < fill_cnt {
        if my_orders.fill_side(i) == 0 {
            remaining = remaining - my_orders.fill_amount(i);
        }
        i += 1;
    }

    if remaining <= 0 {
        return;
    }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    if price_history.len() == 5 {
        let old_price = price_history[0];
        let jump = (market.price - old_price) * 10000 / old_price;
        if jump > 200 {
            orders.submit_market_buy(remaining);
            remaining = 0;
            return;
        }
    }

    let lookback = 5;
    let vol_sum = 0;
    let idx = 0;
    while idx < lookback && idx < market.history_len() {
        vol_sum = vol_sum + market.history_volume(idx);
        idx += 1;
    }
    let avg_vol = if idx > 0 { vol_sum / idx } else { 1 };

    let slice_base = remaining * market.volume / avg_vol;
    let slice = clamp_val(slice_base, 10, 1000);
    let order_amount = if slice < remaining { slice } else { remaining };

    if order_amount > 0 {
        let bid = market.bid_price_0;
        if bid > 0 {
            orders.submit_limit_buy(bid, order_amount);
        }
    }
}