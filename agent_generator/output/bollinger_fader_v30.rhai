let initialized = false;
let stop_loss_threshold = 0;
let last_prices = [];
let panic_mode = false;
let fomo_triggered = false;
let last_decision_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(50_000, 200_000);
    }

    if !market.trading_enabled { return; }

    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if panic_mode {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    if account.unrealized_pnl < stop_loss_threshold && account.unrealized_pnl < 0 {
        panic_mode = true;
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    last_prices.push(market.price);
    if last_prices.len() > 10 {
        last_prices.remove(0);
    }

    if last_prices.len() >= 6 {
        let delayed_price = last_prices[last_prices.len() - 6];
        let current_delayed_price = last_prices[last_prices.len() - 1];

        if last_prices.len() >= 11 {
            let old_price = last_prices[last_prices.len() - 11];
            if old_price != 0 {
                let change = (current_delayed_price - old_price) * 10000 / old_price;
                if change > 200 && !fomo_triggered {
                    fomo_triggered = true;
                    let buy_amount = account.cash * 1_000_000 / market.price;
                    if buy_amount > 0 {
                        orders.submit_market_buy(buy_amount);
                    }
                    return;
                }
            }
        }

        if !fomo_triggered && last_decision_price == 0 {
            last_decision_price = delayed_price;
        }

        if !fomo_triggered && last_decision_price != 0 && last_prices.len() >= 6 {
            let upper_band = market.ma_20 + 2 * market.std_dev;
            let lower_band = market.ma_20 - 2 * market.std_dev;

            if account.cash > lower_band * 100 {
                orders.submit_limit_buy(lower_band, 100);
            }

            if account.stock >= 100 {
                orders.submit_limit_sell(upper_band, 100);
            }
        }
    }
}