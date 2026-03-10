let initialized = false;
let delayed_prices = [];
let delayed_highs = [];
let stop_loss_offset = 0;
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_offset = rng.rand_int(50_000, 200_000);
    }

    if !market.trading_enabled { return; }

    delayed_prices.push(market.price);
    delayed_highs.push(market.high_20);

    if delayed_prices.len() > 20 {
        delayed_prices.remove(0);
        delayed_highs.remove(0);
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }

    if account.stock > 0 {
        let stop_price = account.avg_cost - stop_loss_offset;
        if market.price <= stop_price {
            orders.submit_market_sell(account.stock);
        }
        return;
    }

    if delayed_prices.len() < 6 { return; }

    let current_price = delayed_prices[delayed_prices.len() - 1];
    let price_3_ago = delayed_prices[delayed_prices.len() - 4];
    if price_3_ago > 0 && ((current_price - price_3_ago) * 100 / price_3_ago) > 2 {
        fomo_triggered = true;
    }

    if fomo_triggered {
        let buy_amount = (account.cash * 800 / 1000) / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        fomo_triggered = false;
        return;
    }

    let delayed_price = delayed_prices[delayed_prices.len() - 6];
    let delayed_high = delayed_highs[delayed_highs.len() - 6];

    if delayed_price > delayed_high {
        let buy_amount = (account.cash * 900 / 1000) / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    }
}