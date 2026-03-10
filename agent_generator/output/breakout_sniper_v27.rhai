let initialized = false;
let lot_size_percent = 0;
let stop_loss_ticks = 0;
let in_trade = false;
let entry_avg_cost = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size_percent = rng.rand_int(40, 55);
        stop_loss_ticks = rng.rand_int(3, 8);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let morning_boundary = market.total_ticks * 2 / 10;
    if market.tick >= morning_boundary {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    if account.stock > 0 {
        in_trade = true;
        if account.avg_cost > 0 {
            let stop_price = account.avg_cost - stop_loss_ticks * 10000;
            if market.price <= stop_price {
                orders.submit_market_sell(account.stock);
                in_trade = false;
                entry_avg_cost = 0;
            }
        }
    } else {
        in_trade = false;
        entry_avg_cost = 0;
    }

    if !in_trade && market.price > market.high_20 {
        let cash_to_use = account.cash * lot_size_percent / 100;
        let shares_to_buy = cash_to_use / market.price;
        if shares_to_buy > 0 {
            orders.submit_market_buy(shares_to_buy);
            in_trade = true;
        }
    }
}