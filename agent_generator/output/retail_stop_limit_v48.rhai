let initialized = false;
let personality = 0;
let trade_entered = false;
let entry_price = 0;
let lot_size = 0;
let take_profit_order_id = 0;
let strategy_completed = false;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        personality = rng.rand_int(0, 1);
    }

    if strategy_completed { return; }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if !trade_entered {
        if personality == 0 {
            if market.std_dev > market.price * 50 / 10000 {
                return;
            }
            let max_cash = account.cash * 5 / 100;
            let estimated_shares = max_cash / market.price;
            if estimated_shares == 0 { return; }
            lot_size = rng.rand_int(1, estimated_shares);
        } else {
            let max_cash = account.cash * 50 / 100;
            let estimated_shares = max_cash / market.price;
            if estimated_shares == 0 { return; }
            lot_size = rng.rand_int(estimated_shares * 30 / 100, estimated_shares);
        }

        let should_enter = rng.rand_bool(5);
        if should_enter && lot_size > 0 {
            orders.submit_market_buy(lot_size);
            trade_entered = true;
            entry_price = market.price;
        }
    } else {
        let stop_loss_price = entry_price * 98 / 100;
        let take_profit_price = entry_price * 105 / 100;

        if market.price <= stop_loss_price {
            orders.submit_market_sell(lot_size);
            trade_entered = false;
            strategy_completed = true;
            return;
        }

        take_profit_order_id = orders.submit_limit_sell(take_profit_price, lot_size);

        let fill_count = my_orders.fill_count();
        let j = 0;
        while j < fill_count {
            let fill_id = my_orders.fill_id(j);
            if fill_id == take_profit_order_id {
                strategy_completed = true;
                trade_entered = false;
                break;
            }
            j += 1;
        }
    }
}