let initialized = false;
let price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        for i in range(0, 5) {
            price_history.push(market.price);
        }
    }

    if !market.trading_enabled { return; }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    let fomo_triggered = false;
    if price_history.len() == 5 {
        let old_price = price_history[0];
        let current_price = price_history[4];
        let jump_threshold = old_price * 200 / 10000;
        if (current_price - old_price) > jump_threshold {
            fomo_triggered = true;
            let buy_amount = 100;
            orders.submit_market_buy(buy_amount);
        }
    }

    if !fomo_triggered && market.tick % 50 == 0 {
        if market.buy_volume > (market.sell_volume * 3) {
            let buy_amount = 100;
            orders.submit_market_buy(buy_amount);
        }
    }
}