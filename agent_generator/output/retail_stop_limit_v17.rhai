let initialized = false;
let state = 0;
let entry_price = 0;
let lot_size = 0;
let tp_order_id = 0;
let sl_active = false;
let order_placed_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_cap = account.total_equity * 5 / 100;
        let max_shares = max_cap / market.price;
        if max_shares > 0 {
            lot_size = rng.rand_int(1, max_shares);
        } else {
            lot_size = 0;
        }
    }

    if !market.trading_enabled || market.bid_price_0 == 0 || market.ask_price_0 == 0 || market.std_dev > 5_000_000 {
        return;
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        if oid != tp_order_id {
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    if state == 0 {
        if lot_size == 0 {
            return;
        }
        if rng.rand_bool(1) && account.stock == 0 {
            let bid_price = market.bid_price_0 + 1;
            entry_price = market.price;
            orders.submit_limit_buy(bid_price, lot_size);
            state = 1;
            sl_active = false;
            order_placed_tick = market.tick;
        }
    } else if state == 1 {
        if account.stock >= lot_size {
            let tp_price = entry_price * 105 / 100;
            tp_order_id = orders.submit_limit_sell(tp_price, lot_size);
            order_placed_tick = market.tick;
            state = 2;
        } else if market.tick - order_placed_tick > 3 {
            let bid_price = market.bid_price_0 + 1;
            orders.submit_limit_buy(bid_price, lot_size);
            order_placed_tick = market.tick;
        }
    } else if state == 2 {
        if account.stock == 0 {
            state = 0;
            tp_order_id = 0;
            return;
        }

        let sl_price = entry_price * 98 / 100;
        if market.price <= sl_price && !sl_active {
            orders.submit_market_sell(lot_size);
            sl_active = true;
            tp_order_id = 0;
            return;
        }

        let tp_found = false;
        let pending_cnt2 = my_orders.pending_count();
        let j = 0;
        while j < pending_cnt2 {
            let pid = my_orders.pending_id(j);
            if pid == tp_order_id {
                tp_found = true;
                if market.tick - order_placed_tick > 3 {
                    orders.submit_cancel(tp_order_id);
                    let tp_price = entry_price * 105 / 100;
                    tp_order_id = orders.submit_limit_sell(tp_price, lot_size);
                    order_placed_tick = market.tick;
                }
                break;
            }
            j += 1;
        }

        if !tp_found && account.stock > 0 && !sl_active {
            let tp_price = entry_price * 105 / 100;
            tp_order_id = orders.submit_limit_sell(tp_price, lot_size);
            order_placed_tick = market.tick;
        }
    }
}