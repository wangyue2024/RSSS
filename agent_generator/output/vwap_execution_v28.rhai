let total_target = 10_000_000;
let remaining = total_target;
let order_age_map = [];

fn on_tick() {
    if (!market.trading_enabled) { return; }

    let current_tick = market.tick;

    let i = 0;
    let pending_cnt = my_orders.pending_count();
    while (i < pending_cnt) {
        let oid = my_orders.pending_id(i);
        let placed_tick = my_orders.pending_placed_tick(i);

        if (current_tick - placed_tick >= 3) {
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    let fill_cnt = my_orders.fill_count();
    let j = 0;
    while (j < fill_cnt) {
        let fill_side = my_orders.fill_side(j);
        if (fill_side == 0) {
            let fill_amt = my_orders.fill_amount(j);
            remaining -= fill_amt;
        }
        j += 1;
    }

    if (remaining <= 0) { return; }

    if (my_orders.pending_count() == 0) {
        let lookback = 5;
        let total_vol = 0;
        let idx = 0;
        while (idx < lookback && idx < market.history_len()) {
            total_vol += market.history_volume(idx);
            idx += 1;
        }
        let avg_vol = 0;
        if (idx > 0) {
            avg_vol = total_vol / idx;
        } else {
            avg_vol = 100;
        }

        let slice = (avg_vol * 10) / 100;
        if (slice < 1) { slice = 1; }
        if (slice > remaining) { slice = remaining; }

        let buy_price = market.ask_price_0;
        if (buy_price > 0 && slice > 0) {
            orders.submit_limit_buy(buy_price, slice);
        }
    }
}