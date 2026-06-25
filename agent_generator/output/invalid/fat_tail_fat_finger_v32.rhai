let initialized = false;
let base_lot = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let pos = account.stock;
    let avg = account.avg_cost;
    let current_price = market.price;
    let is_at_loss = false;
    if pos > 0 && current_price < avg {
        is_at_loss = true;
    } else if pos < 0 && current_price > avg {
        is_at_loss = true;
    }

    let current_lot = base_lot;
    if is_at_loss {
        current_lot = base_lot * 2;
    }

    let fat_finger = rng.rand_int(0, 9999) == 0;
    let normal_trade = rng.rand_int(0, 999) == 0;

    if fat_finger {
        if rng.rand_bool(50) {
            orders.submit_market_buy(current_lot * 100);
        } else {
            orders.submit_market_sell(current_lot * 100);
        }
    } else if normal_trade {
        if rng.rand_bool(50) {
            let bid_price = market.bid_price_0;
            if bid_price > 0 {
                orders.submit_limit_buy(bid_price + 1, current_lot);
            }
        } else {
            let ask_price = market.ask_price_0;
            if ask_price > 0 {
                orders.submit_limit_sell(ask_price - 1, current_lot);
            }
        }
    }
}