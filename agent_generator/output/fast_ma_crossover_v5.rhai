let initialized = false;
let prev_ma5 = 0;
let prev_ma20 = 0;
let stop_loss_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(10_000, 50_000);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    let ma5 = market.ma_5;
    let ma20 = market.ma_20;

    if prev_ma5 <= prev_ma20 && ma5 > ma20 && account.stock == 0 {
        let cash_to_use = account.cash * 95 / 100;
        let buy_amount = cash_to_use / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    } else if prev_ma5 >= prev_ma20 && ma5 < ma20 && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }

    prev_ma5 = ma5;
    prev_ma20 = ma20;
}