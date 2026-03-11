let initialized = false;
let lot_size = 0;
let last_price = 0;
let price_history = [];
let morning_session_end = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        morning_session_end = market.total_ticks / 5;
        let max_shares = account.total_equity * 5 / 100 / market.price;
        if max_shares < 20 {
            lot_size = max_shares;
        } else {
            let upper = max_shares;
            if upper > 100 { upper = 100; }
            lot_size = rng.rand_int(20, upper);
        }
        price_history.push(market.price);
        return;
    }

    if !market.trading_enabled { return; }

    let current_price = market.price;
    price_history.push(current_price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.tick >= morning_session_end {
        last_price = current_price;
        return;
    }

    if market.std_dev * 10000 / market.price > 500 {
        last_price = current_price;
        return;
    }

    if price_history.len() >= 3 {
        let idx = price_history.len() - 1;
        let old_price = price_history[idx - 2];
        let price_jump = (current_price - old_price) * 10000 / old_price;
        if price_jump > 200 && lot_size > 0 {
            orders.submit_market_buy(lot_size);
            last_price = current_price;
            return;
        }
    }

    if market.rsi_14 < 3000 && lot_size > 0 {
        let buy_price = current_price * 99 / 100;
        orders.submit_limit_buy(buy_price, lot_size);
    } else if market.rsi_14 > 7000 && account.stock >= lot_size && lot_size > 0 {
        let sell_price = current_price * 101 / 100;
        orders.submit_limit_sell(sell_price, lot_size);
    }

    last_price = current_price;
}