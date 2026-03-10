let initialized = false;
let breakout_triggered = false;
let stop_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;
    let total_ticks = market.total_ticks;
    let is_morning = current_tick < total_ticks / 5;

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if !is_morning {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    let current_price = market.price;
    let high_20 = market.high_20;
    let avg_cost = account.avg_cost;

    if !breakout_triggered && account.stock == 0 {
        if current_price > high_20 {
            breakout_triggered = true;
            let cash_to_use = account.cash * 80 / 100;
            let buy_amount = cash_to_use / current_price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
    } else if account.stock > 0 && avg_cost > 0 {
        if stop_price == 0 {
            stop_price = avg_cost * 98 / 100;
        }
        if current_price <= stop_price {
            orders.submit_market_sell(account.stock);
            breakout_triggered = false;
            stop_price = 0;
        }
    } else {
        breakout_triggered = false;
        stop_price = 0;
    }
}