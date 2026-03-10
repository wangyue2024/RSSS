let initialized = false;
let entered = false;
let has_exited = false;
let entry_price = 0;
let price_history = [];
let lot_size = 0;
let take_profit_order_id = -1;

fn round_to_dollar(price) {
    ((price + 500_000) / 1_000_000) * 1_000_000
}

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_capital_5_percent = account.total_equity * 5 / 100;
        let max_shares = max_capital_5_percent / market.price;
        if max_shares > 0 {
            lot_size = rng.rand_int(1, max_shares);
        } else {
            lot_size = 0;
        }
    }

    if !market.trading_enabled {
        return;
    }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    if price_history.len() < 5 {
        return;
    }

    let delayed_price = price_history[0];

    if market.std_dev > 50_000 {
        return;
    }

    if has_exited {
        return;
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if !entered {
        if rng.rand_bool(1) && lot_size > 0 {
            orders.submit_market_buy(lot_size);
            entry_price = delayed_price;
            entered = true;
        }
    } else {
        if account.stock == 0 {
            entered = false;
            has_exited = true;
            return;
        }

        let stop_loss_price = entry_price * 98 / 100;
        if delayed_price <= stop_loss_price {
            orders.submit_market_sell(account.stock);
            entered = false;
            has_exited = true;
            return;
        }

        let take_profit_price = round_to_dollar(entry_price * 105 / 100);
        take_profit_order_id = orders.submit_limit_sell(take_profit_price, account.stock);
    }
}