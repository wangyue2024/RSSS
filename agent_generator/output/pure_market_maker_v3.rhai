let initialized = false;
let cash_percent = 0;
let stock_percent = 0;
let spread_micros = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        cash_percent = rng.rand_int(40, 50);
        stock_percent = rng.rand_int(40, 50);
        spread_micros = rng.rand_int(5_000, 20_000);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let mid_price = market.price;
    let buy_price = mid_price - spread_micros;
    let sell_price = mid_price + spread_micros;

    if buy_price > 0 {
        let max_buy_cash = account.cash * cash_percent / 100;
        let buy_amount = max_buy_cash / buy_price;
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }

    let sell_amount = account.stock * stock_percent / 100;
    if sell_amount > 0 && sell_price > 0 {
        orders.submit_limit_sell(sell_price, sell_amount);
    }
}