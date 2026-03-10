let SPREAD = 5000;
let TICK_INTERVAL = 50;
let initialized = false;
let lot_size = 0;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        lot_size = rng.rand_int(10_000, 50_000);
    }

    if market.tick % TICK_INTERVAL != 0 { return; }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let current_price = market.price;
    if current_price == 0 { return; }

    let risk_factor = rng.rand_int(30, 100);
    let max_cash_use = account.cash * risk_factor / 100;
    let max_buy_amount = max_cash_use / current_price;
    if max_buy_amount > 0 {
        let buy_amount = max_buy_amount * lot_size / 100;
        if buy_amount > 0 {
            let bid_price = current_price - SPREAD;
            if bid_price > 0 {
                orders.submit_limit_buy(bid_price, buy_amount);
            }
        }
    }

    let max_sell_amount = account.stock * risk_factor / 100;
    if max_sell_amount > 0 {
        let sell_amount = max_sell_amount * lot_size / 100;
        if sell_amount > 0 {
            let ask_price = current_price + SPREAD;
            orders.submit_limit_sell(ask_price, sell_amount);
        }
    }
}