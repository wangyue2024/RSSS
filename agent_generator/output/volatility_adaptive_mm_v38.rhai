let initialized = false;
let lot_size = 0;
let last_decision_tick = -100;

fn on_tick() {
    if !initialized {
        initialized = true;
        let five_percent_cap = (account.total_equity * 50000) / 1_000_000;
        let max_shares = five_percent_cap / market.price;
        if max_shares < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;

    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if current_tick % 50 != 0 { return; }
    last_decision_tick = current_tick;

    let vol = market.std_dev;
    let high_vol_threshold = 100_000;

    if vol > high_vol_threshold {
        return;
    }

    let mid_price = market.price;
    let base_spread = 2_000;
    let vol_adjustment = (vol * base_spread) / 50_000;
    let spread = base_spread + vol_adjustment;
    let half_spread = spread / 2;

    let bid_price = mid_price - half_spread;
    let ask_price = mid_price + half_spread;

    if bid_price > 0 {
        orders.submit_limit_buy(bid_price, lot_size);
    }
    orders.submit_limit_sell(ask_price, lot_size);
}