let initialized = false;
let panic_threshold = 0;
let price_history = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(10_000, 50_000);
    }

    if !market.trading_enabled {
        return;
    }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    if price_history.len() == 5 {
        let old_price = price_history[0];
        let price_jump = market.price - old_price;
        let jump_threshold = old_price * 200 / 10000;
        if price_jump > jump_threshold {
            fomo_triggered = true;
        }
    }

    if fomo_triggered {
        let max_buy = account.cash / market.price;
        if max_buy > 0 {
            let buy_qty = rng.rand_int(1, max_buy);
            if buy_qty > 0 {
                orders.submit_market_buy(buy_qty);
            }
        }
        fomo_triggered = false;
        return;
    }

    let rand = rng.rand_int(0, 99);
    if rand < 5 {
        let offset = rng.rand_int(-100, 100);
        let price = market.price + offset;
        let max_qty = account.cash / price;
        if max_qty > 0 {
            let qty = rng.rand_int(1, max_qty);
            if qty > 0 {
                orders.submit_limit_buy(price, qty);
            }
        }
    } else if rand > 95 {
        if account.stock > 0 {
            let offset = rng.rand_int(-100, 100);
            let price = market.price + offset;
            let qty = rng.rand_int(1, account.stock);
            if qty > 0 {
                orders.submit_limit_sell(price, qty);
            }
        }
    }
}