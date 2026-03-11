let entered = false;
let take_profit_order_id = 0;
let stop_loss_trigger_price = 0;
let cost_basis = 0;

fn on_tick() {
    if !market.trading_enabled { return; }

    // Cancel any pending orders if we have no position
    if account.stock == 0 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        entered = false;
        take_profit_order_id = 0;
        return;
    }

    // Random entry
    if !entered && rng.rand_bool(1) && account.cash > 0 {
        let max_shares = account.cash / market.price;
        let buy_amount = clamp_val(rng.rand_int(1, max_shares), 1, 100);
        orders.submit_market_buy(buy_amount);
        entered = true;
        cost_basis = account.avg_cost;
        stop_loss_trigger_price = cost_basis * 98 / 100;
        return;
    }

    // If we have position but no take-profit order, place it
    if entered && take_profit_order_id == 0 && account.stock > 0 {
        let take_profit_price = cost_basis * 105 / 100 + 1;
        take_profit_order_id = orders.submit_limit_sell(take_profit_price, account.stock);
        return;
    }

    // Check stop-loss condition
    if entered && account.stock > 0 && market.price <= stop_loss_trigger_price {
        orders.submit_market_sell(account.stock);
        entered = false;
        take_profit_order_id = 0;
        return;
    }
}