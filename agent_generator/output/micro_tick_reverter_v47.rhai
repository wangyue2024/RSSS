let initialized = false;
let prev_price = 0;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(5000, 25000);
    }

    if !market.trading_enabled { return; }

    let cur_price = market.price;

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        prev_price = cur_price;
        return;
    }

    if prev_price != 0 && prev_price > cur_price {
        let buy_price = cur_price - 1;
        if buy_price > 0 {
            orders.submit_limit_buy(buy_price, 100);
        }
    } else if prev_price != 0 && prev_price < cur_price {
        if cur_price > account.avg_cost && account.stock > 0 {
            let sell_price = cur_price + 1;
            orders.submit_limit_sell(sell_price, 100);
        }
    }

    prev_price = cur_price;
}