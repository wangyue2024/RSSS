let initialized = false;
let fair_value_micros = 0;
let price_history = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        let base_fair_value = 100_000_000;
        let random_adjustment = rng.rand_int(-5_000_000, 5_000_000);
        fair_value_micros = base_fair_value + random_adjustment;
        price_history.push(market.price);
    }
    
    if !market.trading_enabled { return; }

    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    if price_history.len() == 5 {
        let old_price = price_history[0];
        if old_price > 0 && market.price * 100 > old_price * 102 {
            fomo_triggered = true;
            let buy_amount = account.cash / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }

    fomo_triggered = false;

    let threshold1 = fair_value_micros * 105 / 100;
    let threshold2 = fair_value_micros * 110 / 100;
    let current_price = market.price;

    if current_price > fair_value_micros && account.stock > 0 {
        let sell_amount;
        if current_price > threshold2 {
            sell_amount = account.stock * 50 / 100;
            if sell_amount == 0 { sell_amount = 1; }
            if sell_amount > account.stock { sell_amount = account.stock; }
            orders.submit_market_sell(sell_amount);
        } else if current_price > threshold1 {
            sell_amount = account.stock * 10 / 100;
            if sell_amount == 0 { sell_amount = 1; }
            if sell_amount > account.stock { sell_amount = account.stock; }
            orders.submit_market_sell(sell_amount);
        }
    }
}