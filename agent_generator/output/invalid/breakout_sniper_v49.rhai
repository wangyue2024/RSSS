let initialized = false;
let panic_threshold = 0;
let delayed_prices = [];
let fomo_triggered = false;
let fomo_cooldown = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = rng.rand_int(-500000, -100000);
    }

    if !market.trading_enabled {
        return;
    }

    delayed_prices.push(market.price);
    if delayed_prices.len() > 5 {
        delayed_prices.remove(0);
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if fomo_triggered {
        fomo_cooldown += 1;
        if fomo_cooldown >= 10 {
            fomo_triggered = false;
            fomo_cooldown = 0;
        }
    }

    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        fomo_triggered = false;
        return;
    }

    if delayed_prices.len() >= 5 {
        let current_price = delayed_prices[4];
        let old_price = delayed_prices[0];
        if !fomo_triggered && old_price > 0 {
            let percent_change = (current_price - old_price) * 100 / old_price;
            if percent_change > 2 {
                let buy_amount = account.cash / market.ask_price_0;
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                    fomo_triggered = true;
                    fomo_cooldown = 0;
                    return;
                }
            }
        }
    }

    if account.stock > 0 {
        if delayed_prices.len() >= 2 && account.avg_cost > 0 {
            let check_price = delayed_prices[delayed_prices.len() - 2];
            let stop_price = account.avg_cost * 98 / 100;
            if check_price < stop_price {
                orders.submit_market_sell(account.stock);
                return;
            }
        }
    }

    if delayed_prices.len() >= 5 && !fomo_triggered {
        let current_delayed = delayed_prices[4];
        if current_delayed > market.high_20 {
            let buy_amount = account.cash * 70 / 100 / market.ask_price_0;
            if buy_amount > 0 {
                orders.submit_limit_buy(market.ask_price_0, buy_amount);
            }
        }
    }
}