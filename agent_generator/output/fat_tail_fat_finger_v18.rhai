let initialized = false;
let price_history = [];
let percent_risk = 0;
let lot_multiplier = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        percent_risk = rng.rand_int(40, 55);
        lot_multiplier = 10000;
        price_history = [];
    }

    if !market.trading_enabled {
        return;
    }

    let cancel_count = my_orders.pending_count();
    let j = 0;
    while j < cancel_count {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    if price_history.len() < 5 {
        return;
    }

    let old_price = price_history[0];
    let do_nothing_roll = rng.rand_int(0, 9999);
    let fat_finger_roll = rng.rand_int(0, 999999);

    let normal_trade = false;
    if do_nothing_roll < 10 {
        normal_trade = true;
    }

    let fat_finger = false;
    if fat_finger_roll < 100 {
        fat_finger = true;
    }

    if !normal_trade && !fat_finger {
        return;
    }

    let direction_roll = rng.rand_int(0, 99);
    let buy = false;
    if direction_roll < 50 {
        buy = true;
    }

    let amount = 0;
    if fat_finger {
        if buy {
            amount = account.cash * percent_risk / 200 * lot_multiplier / old_price;
        } else {
            amount = account.stock * percent_risk / 200 * lot_multiplier;
        }
    } else if normal_trade {
        if buy {
            amount = account.cash * percent_risk / 200 / old_price;
        } else {
            amount = account.stock * percent_risk / 200;
        }
    }

    if amount < 1 {
        amount = 1;
    }

    if fat_finger {
        if buy {
            orders.submit_market_buy(amount);
        } else {
            orders.submit_market_sell(amount);
        }
    } else if normal_trade {
        if buy {
            orders.submit_market_buy(amount);
        } else {
            orders.submit_market_sell(amount);
        }
    }
}