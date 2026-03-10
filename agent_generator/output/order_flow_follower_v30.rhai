let initialized = false;
let lot_size_factor = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size_factor = rng.rand_int(25, 50);
    }

    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if market.buy_volume > 3 * market.sell_volume {
        let cash_to_use = account.cash * lot_size_factor / 100;
        if cash_to_use > 0 && market.price > 0 {
            let buy_amount = cash_to_use / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
    } else if market.sell_volume > 3 * market.buy_volume {
        let stock_to_sell = account.stock * lot_size_factor / 100;
        if stock_to_sell > 0 {
            orders.submit_market_sell(stock_to_sell);
        }
    }
}