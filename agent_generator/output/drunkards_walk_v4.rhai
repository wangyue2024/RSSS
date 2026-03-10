let initialized = false;
let lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let cash_pct = rng.rand_int(2500, 5000);
        let max_shares = (account.cash * cash_pct) / (10000 * market.price);
        lot_size = rng.rand_int(1, max_shares);
        if (lot_size < 1) {
            lot_size = 1;
        }
    }

    if !market.trading_enabled {
        return;
    }

    if (market.tick >= (market.total_ticks / 5)) {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while (i < count) {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let roll = rng.rand_int(0, 99);
    if (roll < 5) {
        let price_offset = rng.rand_int(-200, 200);
        let limit_price = market.price + price_offset;
        let qty = rng.rand_int(1, lot_size);
        if (qty > 0) {
            orders.submit_limit_buy(limit_price, qty);
        }
    } else if (roll > 95) {
        let price_offset = rng.rand_int(-200, 200);
        let limit_price = market.price + price_offset;
        let max_sell = account.stock;
        let qty = rng.rand_int(1, lot_size);
        if (qty > 0 && qty <= max_sell) {
            orders.submit_limit_sell(limit_price, qty);
        }
    }
}