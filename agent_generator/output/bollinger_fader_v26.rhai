let price_history = [];
let fomo_triggered = false;

fn on_tick() {
    if !market.trading_enabled { return; }

    // Update FOMO price history every tick
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    // Check FOMO condition
    if price_history.len() == 5 {
        let old_price = price_history[0];
        let new_price = price_history[4];
        let threshold = old_price + (old_price * 2 / 100);
        if new_price > threshold {
            fomo_triggered = true;
        }
    }

    // Cancel all pending orders if we are about to act
    if fomo_triggered || market.tick % 50 == 0 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
    }

    // FOMO action - market buy immediately
    if fomo_triggered {
        let buy_amount = (account.cash / 2) / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        fomo_triggered = false;
        return;
    }

    // Lazy trader - only run core strategy every 50 ticks
    if market.tick % 50 != 0 {
        return;
    }

    // Bollinger Band calculations
    let ma = market.ma_20;
    let std = market.std_dev;
    let upper_band = ma + 2 * std;
    let lower_band = ma - 2 * std;

    // Place limit buy at lower band
    if lower_band > 0 {
        let buy_amount = (account.cash * 10 / 100) / lower_band;
        if buy_amount > 0 {
            orders.submit_limit_buy(lower_band, buy_amount);
        }
    }

    // Place limit sell at upper band
    if upper_band > 0 && account.stock > 0 {
        let sell_amount = account.stock * 10 / 100;
        if sell_amount == 0 {
            sell_amount = 1;
        }
        if sell_amount > account.stock {
            sell_amount = account.stock;
        }
        orders.submit_limit_sell(upper_band, sell_amount);
    }
}