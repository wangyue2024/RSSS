let initialized = false;
let prev_ma_above = false;
let my_lot_base = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        my_lot_base = rng.rand_int(500_000, 5_000_000);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let morning_period = market.tick < (market.total_ticks * 2 / 10);
    if !morning_period { return; }

    let ma5 = market.ma_5;
    let ma20 = market.ma_20;
    let cross_above = ma5 > ma20;

    if cross_above && !prev_ma_above {
        let cash_to_use = account.cash * rng.rand_int(250, 500) / 1000;
        let lot = cash_to_use / market.bid_price_0;
        let buy_qty = if lot > my_lot_base { lot } else { my_lot_base };
        if buy_qty > 0 && market.bid_price_0 > 0 {
            let my_bid = market.bid_price_0 + 1;
            orders.submit_limit_buy(my_bid, buy_qty);
        }
    } else if !cross_above && prev_ma_above && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }

    prev_ma_above = cross_above;
}