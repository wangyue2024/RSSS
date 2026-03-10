let initialized = false;
let last_action_tick = 0;
let ma5_above_ma20_last = false;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        ma5_above_ma20_last = market.ma_5 > market.ma_20;
    }

    if market.tick % 50 != 0 { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let ma5_above_ma20_now = market.ma_5 > market.ma_20;

    if ma5_above_ma20_now && !ma5_above_ma20_last {
        if account.cash > market.price {
            let buy_amount = account.cash / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
    }

    if !ma5_above_ma20_now && ma5_above_ma20_last && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }

    ma5_above_ma20_last = ma5_above_ma20_now;
}