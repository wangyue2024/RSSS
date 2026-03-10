let initialized = false;
let lot_size = 0;

fn on_tick() {
    if !initialized {
        let max_cap_for_trade = account.total_equity * 5 / 100;
        let price = market.price;
        if price > 0 {
            lot_size = max_cap_for_trade / price;
            if lot_size < 1 {
                lot_size = 1;
            }
        } else {
            lot_size = 1;
        }
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let fat_finger = rng.rand_int(1, 10000) == 1;

    if fat_finger {
        let fat_amount = lot_size * 100;
        if rng.rand_bool(50) {
            orders.submit_market_buy(fat_amount);
        } else {
            orders.submit_market_sell(fat_amount);
        }
        return;
    }

    let volatility_threshold = market.price * 5 / 100;
    if market.std_dev > volatility_threshold {
        return;
    }

    let place_order = rng.rand_int(1, 100) == 1;
    if !place_order {
        return;
    }

    let rounded_price = (market.price + 500_000) / 1_000_000 * 1_000_000;

    if rng.rand_bool(50) {
        if market.price > account.avg_cost && account.stock >= lot_size {
            orders.submit_limit_sell(rounded_price, lot_size);
        }
    } else {
        let cost = rounded_price * lot_size;
        if cost <= account.cash {
            orders.submit_limit_buy(rounded_price, lot_size);
        }
    }
}