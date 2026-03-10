let target_shares = 10_000;
let bought_so_far = 0;
let initialized = false;
let pending_order_placed_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    if market.tick >= market.total_ticks / 5 {
        return;
    }

    let current_fills_buy = 0;
    let fill_count = my_orders.fill_count();
    let i = 0;
    while i < fill_count {
        if my_orders.fill_side(i) == 0 {
            current_fills_buy += my_orders.fill_amount(i);
        }
        i += 1;
    }
    bought_so_far += current_fills_buy;

    let fomo_triggered = false;
    if market.history_len() > 5 {
        let old_price = market.history_price(5);
        if old_price != 0 {
            let change = (market.price - old_price) * 10000 / old_price;
            if change > 200 {
                fomo_triggered = true;
            }
        }
    }

    if fomo_triggered {
        let remaining = target_shares - bought_so_far;
        if remaining > 0 {
            orders.submit_market_buy(remaining);
        }
        return;
    }

    let pending_count = my_orders.pending_count();
    i = 0;
    while i < pending_count {
        let placed = my_orders.pending_placed_tick(i);
        if market.tick - placed >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if my_orders.pending_count() == 0 {
        let remaining = target_shares - bought_so_far;
        if remaining <= 0 {
            return;
        }

        let lookback = 10;
        let total_vol = 0;
        let count = 0;
        let idx = 1;
        while idx <= lookback && idx < market.history_len() {
            total_vol += market.history_volume(idx);
            count += 1;
            idx += 1;
        }
        let avg_vol = if count > 0 { total_vol / count } else { 100 };

        let slice = avg_vol * 10 / 100;
        let order_size = slice;
        if order_size < 1 {
            order_size = 1;
        }
        if order_size > remaining {
            order_size = remaining;
        }

        let bid_price = market.bid_price_0;
        if bid_price != 0 && order_size > 0 {
            orders.submit_limit_buy(bid_price, order_size);
            pending_order_placed_tick = market.tick;
        }
    }
}