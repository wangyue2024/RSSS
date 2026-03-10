let initialized = false;
let lot_size = 0;
let std_dev_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_capital_for_trade = account.total_equity * 5 / 100;
        let price = market.price;
        if price > 0 {
            lot_size = max_capital_for_trade / price;
            if lot_size < 1 {
                lot_size = 1;
            }
        } else {
            lot_size = 1;
        }
        std_dev_threshold = price * 10 / 100;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.std_dev > std_dev_threshold {
        return;
    }

    if rng.rand_int(0, 9999) == 0 {
        let fat_finger_amount = lot_size * 100;
        if rng.rand_bool(50) {
            orders.submit_market_buy(fat_finger_amount);
        } else {
            orders.submit_market_sell(fat_finger_amount);
        }
        return;
    }

    if rng.rand_bool(5) {
        if rng.rand_bool(50) && market.bid_price_0 > 0 {
            let my_bid = market.bid_price_0 + 1;
            orders.submit_limit_buy(my_bid, lot_size);
        } else if market.ask_price_0 > 0 {
            let my_ask = market.ask_price_0 - 1;
            orders.submit_limit_sell(my_ask, lot_size);
        }
    }
}