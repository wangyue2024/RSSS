let initialized = false;
let entered = false;
let take_profit_price = 0;
let panic_threshold = 0;
let cost_basis = 0;
let pending_tp_id = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(1000, 5000);
    }

    if !market.trading_enabled {
        return;
    }

    let i = 0;
    while i < my_orders.pending_count() {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    if !entered {
        if rng.rand_bool(1) && account.cash > 0 {
            let amt = account.cash / market.ask_price_0;
            if amt > 0 {
                orders.submit_market_buy(amt);
                entered = true;
            }
        }
    } else {
        if cost_basis == 0 && account.stock > 0 {
            cost_basis = account.avg_cost;
            take_profit_price = cost_basis * 105 / 100;
            pending_tp_id = orders.submit_limit_sell(take_profit_price, account.stock);
        }

        if account.unrealized_pnl < panic_threshold && account.stock > 0 {
            orders.submit_market_sell(account.stock);
            entered = false;
            cost_basis = 0;
            pending_tp_id = -1;
        }

        let stop_price = cost_basis * 98 / 100;
        if market.price <= stop_price && account.stock > 0 {
            orders.submit_market_sell(account.stock);
            entered = false;
            cost_basis = 0;
            pending_tp_id = -1;
        }
    }
}