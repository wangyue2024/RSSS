let initialized = false;
let lot_size = 0;
let last_ma5 = 0;
let last_ma20 = 0;
let last_signal = 0;
let last_action_tick = 0;

fn on_tick() {
    if !initialized {
        let five_percent_cap = account.total_equity * 500 / 10000;
        let max_shares = five_percent_cap / market.price;
        if max_shares < 1 {
            max_shares = 1;
        }
        lot_size = rng.rand_int(1, max_shares);
        last_ma5 = market.ma_5;
        last_ma20 = market.ma_20;
        initialized = true;
    }

    if !market.trading_enabled {
        return;
    }

    let current_tick = market.tick;
    if current_tick - last_action_tick < 50 {
        return;
    }

    let two_percent_price = market.price * 200 / 10000;
    if market.std_dev > two_percent_price {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    let ma5 = market.ma_5;
    let ma20 = market.ma_20;
    let new_signal = 0;

    if ma5 > ma20 && last_ma5 <= last_ma20 {
        new_signal = 1;
    } else if ma5 < ma20 && last_ma5 >= last_ma20 {
        new_signal = -1;
    }

    if new_signal != last_signal {
        if new_signal == 1 && account.stock == 0 {
            let ask_price = market.ask_price_0;
            orders.submit_limit_buy(ask_price, lot_size);
        } else if new_signal == -1 && account.stock > 0 {
            let bid_price = market.bid_price_0;
            orders.submit_limit_sell(bid_price, account.stock);
        }
        last_signal = new_signal;
        last_action_tick = current_tick;
    }

    last_ma5 = ma5;
    last_ma20 = ma20;
}