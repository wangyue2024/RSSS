let initialized = false;
let buy_triggered = false;
let stop_loss_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let active_period = market.tick < (market.total_ticks / 5);
    if !active_period {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.stock > 0 && market.price <= stop_loss_price {
        orders.submit_market_sell(account.stock);
        buy_triggered = false;
        stop_loss_price = 0;
    } else if !buy_triggered && market.price > market.high_20 && market.price > 0 {
        let buy_amount = (account.cash * 999 / 1000) / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
            buy_triggered = true;
            stop_loss_price = market.price - micros(0, 50);
        }
    }
}