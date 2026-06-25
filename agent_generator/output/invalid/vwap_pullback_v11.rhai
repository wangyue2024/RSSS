let initialized = false;
let last_evaluation_tick = 0;
let recent_prices = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_evaluation_tick = market.tick;
    }

    if !market.trading_enabled { return; }

    let current_tick = market.tick;

    recent_prices.push(market.price);
    if recent_prices.len() > 5 {
        recent_prices.remove(0);
    }

    if recent_prices.len() == 5 && !fomo_triggered {
        let old_price = recent_prices[0];
        let jump_threshold = old_price * 102_000_000 / 100_000_000;
        if market.price >= jump_threshold {
            fomo_triggered = true;
            let cash_to_use = account.cash * 10 / 100;
            let buy_amount = cash_to_use / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }

    if current_tick - last_evaluation_tick >= 50 {
        last_evaluation_tick = current_tick;
        fomo_triggered = false;

        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }

        if account.stock == 0 {
            let threshold = market.vwap * 999_500_000 / 1_000_000_000;
            if market.price < threshold {
                let bid_price = market.price + 1;
                let cash_to_use = account.cash * 50 / 100;
                let buy_amount = cash_to_use / bid_price;
                if buy_amount > 0 {
                    orders.submit_limit_buy(bid_price, buy_amount);
                }
            }
        } else {
            if market.price >= market.vwap {
                orders.submit_limit_sell(market.vwap, account.stock);
            }
        }
    }
}