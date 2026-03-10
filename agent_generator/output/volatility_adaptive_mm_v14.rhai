let initialized = false;
let lot_size = 0;
let max_position = 0;
let volatility_threshold = 50_000;
let base_spread = 1_000;
let max_wait_ticks = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
        let total_cap = account.total_equity;
        let five_percent_cap = total_cap * 5 / 100;
        if market.price > 0 {
            let max_shares = five_percent_cap / market.price;
            if max_shares > 0 {
                lot_size = rng.rand_int(1, max_shares);
                max_position = 5 * lot_size;
            } else {
                lot_size = 1;
                max_position = 5;
            }
        } else {
            lot_size = 100;
            max_position = 500;
        }
    }

    if !market.trading_enabled { return; }

    if market.tick * 5 >= market.total_ticks {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }

    if market.std_dev > volatility_threshold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed = my_orders.pending_placed_tick(i);
        if market.tick - placed >= max_wait_ticks {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    let mid_price;
    if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    } else {
        mid_price = market.price;
    }

    let spread_adjustment = market.std_dev * 2;
    let total_spread = base_spread + spread_adjustment;
    let half_spread = total_spread / 2;

    let buy_price = mid_price - half_spread;
    let sell_price = mid_price + half_spread;

    if account.stock < max_position && lot_size > 0 {
        orders.submit_limit_buy(buy_price, lot_size);
    }

    if account.stock > -max_position && lot_size > 0 {
        orders.submit_limit_sell(sell_price, lot_size);
    }
}