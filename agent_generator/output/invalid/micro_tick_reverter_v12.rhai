let initialized = false;
let offset = 0;
let lot_size = 0;
let last_price = 0;
let pending_order_id = 0;
let order_placed_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        offset = rng.rand_int(1, 3);
        let five_percent_cap = (account.total_equity * 5) / 100;
        let max_shares = five_percent_cap / market.price;
        if max_shares < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
        last_price = market.price;
    }

    if !market.trading_enabled { return; }

    if market.tick >= market.total_ticks / 5 {
        if pending_order_id != 0 {
            orders.submit_cancel(pending_order_id);
            pending_order_id = 0;
        }
        return;
    }

    let vol_threshold = (market.price * 2) / 100;
    if market.std_dev > vol_threshold {
        if pending_order_id != 0 {
            orders.submit_cancel(pending_order_id);
            pending_order_id = 0;
        }
        return;
    }

    if pending_order_id != 0 {
        let found = false;
        let pcount = my_orders.pending_count();
        let i = 0;
        while i < pcount {
            if my_orders.pending_id(i) == pending_order_id {
                found = true;
                if market.tick - order_placed_tick >= 3 {
                    orders.submit_cancel(pending_order_id);
                    pending_order_id = 0;
                }
                break;
            }
            i += 1;
        }
        if !found {
            pending_order_id = 0;
        }
    }

    if pending_order_id == 0 {
        if market.price < last_price {
            let buy_price = market.price - offset;
            if buy_price < 1 { buy_price = 1; }
            pending_order_id = orders.submit_limit_buy(buy_price, lot_size);
            order_placed_tick = market.tick;
        } else if market.price > last_price {
            let sell_price = market.price + offset;
            pending_order_id = orders.submit_limit_sell(sell_price, lot_size);
            order_placed_tick = market.tick;
        }
    }

    last_price = market.price;
}