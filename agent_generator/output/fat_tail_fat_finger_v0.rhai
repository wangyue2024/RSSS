let initialized = false;
let base_lot_size = 0;
let fomo_triggered = false;
let fomo_price = 0;
let last_checked_tick = -100;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = (account.cash * 50 / 100) / market.price;
        if base_lot_size == 0 { base_lot_size = 1; }
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let window = 5;
    if market.history_len() > window {
        let past_price = market.history_price(window);
        let change_pct = (market.price - past_price) * 10000 / past_price;
        if change_pct > 200 && !fomo_triggered {
            fomo_triggered = true;
            fomo_price = market.price;
        }
    }

    if fomo_triggered {
        let buy_amount = account.cash / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        fomo_triggered = false;
        return;
    }

    if rng.rand_int(0, 9999) == 0 {
        let fat_amount = base_lot_size * 100;
        if rng.rand_bool(50) {
            orders.submit_market_buy(fat_amount);
        } else {
            orders.submit_market_sell(fat_amount);
        }
        return;
    }

    if rng.rand_bool(10) && market.tick - last_checked_tick > 10 {
        last_checked_tick = market.tick;
        let side = rng.rand_bool(50);
        let price_adj = 0;
        if side && market.ask_price_0 > 0 {
            price_adj = market.ask_price_0 - 1;
        } else if !side && market.bid_price_0 > 0 {
            price_adj = market.bid_price_0 + 1;
        }
        if price_adj > 0 {
            let order_amount = base_lot_size + rng.rand_int(-5, 5);
            if order_amount < 1 { order_amount = 1; }
            if side {
                orders.submit_limit_buy(price_adj, order_amount);
            } else {
                orders.submit_limit_sell(price_adj, order_amount);
            }
        }
    }
}