let initialized = false;
let lot_size = 0;
let fomo_triggered = false;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        lot_size = rng.rand_int(250000, 500000);
    }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let fomo_window = 5;
    let fomo_threshold = 20000;
    if market.history_len() > fomo_window {
        let old_price = market.history_price(market.history_len() - fomo_window - 1);
        let change = market.price - old_price;
        if change > 0 && change * 100 / old_price > fomo_threshold {
            let buy_amount = account.cash * 50 / 100 / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
                fomo_triggered = true;
                return;
            }
        }
    }

    let rand_val = rng.rand_int(0, 99);
    let is_buy = rand_val < 5;
    let is_sell = rand_val > 95;

    if is_buy {
        let max_cash = account.cash * 50 / 100;
        let rand_cash = rng.rand_int(1, max_cash);
        let buy_amount = rand_cash / market.price;
        if buy_amount > 0 {
            let offset = rng.rand_int(-1000, 1000);
            let bid_price = market.price + offset + 1;
            orders.submit_limit_buy(bid_price, buy_amount);
        }
    }

    if is_sell && account.stock > 0 {
        let max_stock = account.stock * 50 / 100;
        let sell_amount = rng.rand_int(1, max_stock);
        if sell_amount > 0 {
            let offset = rng.rand_int(-1000, 1000);
            let ask_price = market.price + offset;
            orders.submit_limit_sell(ask_price, sell_amount);
        }
    }

    fomo_triggered = false;
}