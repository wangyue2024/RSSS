let initialized = false;
let target_shares = 0;
let base_lot_size = 0;
let total_bought = 0;
let recent_volumes = [];
let volume_sum = 0;
let recent_period = 20;

fn on_tick() {
    if !initialized {
        initialized = true;
        let capital = account.total_equity;
        let five_percent = capital * 5 / 100;
        let max_lot_value = five_percent;
        let price = market.price;
        if price > 0 {
            let max_shares = max_lot_value / price;
            if max_shares > 0 {
                base_lot_size = rng.rand_int(1, max_shares);
                target_shares = max_shares * 2;
            } else {
                base_lot_size = 1;
                target_shares = 10;
            }
        } else {
            base_lot_size = 10;
            target_shares = 100;
        }
        recent_volumes = [];
        volume_sum = 0;
    }

    if !market.trading_enabled { return; }

    let current_price = market.price;
    if current_price == 0 { return; }

    let price_dev = market.std_dev * 100 / current_price;
    if price_dev > 300 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }

    volume_sum += market.volume;
    recent_volumes.push(market.volume);
    if recent_volumes.len() > recent_period {
        let removed = recent_volumes.remove(0);
        volume_sum -= removed;
    }

    let avg_volume = if recent_volumes.len() > 0 { volume_sum / recent_volumes.len() } else { market.volume };
    if avg_volume == 0 { avg_volume = 1; }

    let volume_ratio = market.volume * 100 / avg_volume;
    let dynamic_lot = base_lot_size * volume_ratio / 100;
    let clamped_lot = clamp_val(dynamic_lot, 1, base_lot_size * 2);

    let remaining = target_shares - total_bought;
    if remaining <= 0 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }

    let order_amount = clamped_lot;
    if order_amount > remaining {
        order_amount = remaining;
    }

    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        if my_orders.fill_side(i) == 0 {
            total_bought += my_orders.fill_amount(i);
        }
        i += 1;
    }

    if order_amount <= 0 { return; }

    let pending_cnt = my_orders.pending_count();
    if pending_cnt >= 2 { return; }

    let vwap = market.vwap;
    let bid_price = market.bid_price_0;
    let target_price = if bid_price > 0 && bid_price < vwap { bid_price } else { vwap };
    if target_price <= 0 { target_price = current_price - micros(0, 1); }

    let price_spread = market.ask_price_0 - market.bid_price_0;
    if price_spread > micros(0, 10) {
        target_price = market.bid_price_0;
    }

    if target_price <= 0 { return; }

    orders.submit_limit_buy(target_price, order_amount);
}