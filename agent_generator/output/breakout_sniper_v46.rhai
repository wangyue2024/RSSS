let initialized = false;
let lot_size = 0;
let stop_loss_ticks = 0;

fn on_tick() {
    if !initialized {
        stop_loss_ticks = rng.rand_int(2, 5);
        let max_lot_cash = account.total_equity * 5 / 100;
        let est_price = if market.ask_price_0 > 0 { market.ask_price_0 } else { market.price };
        if est_price > 0 {
            lot_size = max_lot_cash / est_price;
            if lot_size < 1 { lot_size = 1; }
        } else {
            lot_size = 1;
        }
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.tick % 50 != 0 { return; }

    let std_dev_threshold = market.price * 5 / 100;
    if market.std_dev > std_dev_threshold { return; }

    if account.stock > 0 {
        let stop_price = account.avg_cost - stop_loss_ticks * 10000;
        if market.price < stop_price {
            orders.submit_market_sell(account.stock);
        }
    } else {
        if market.price > market.high_20 {
            orders.submit_market_buy(lot_size);
        }
    }
}