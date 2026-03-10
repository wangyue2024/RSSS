let initialized = false;
let lot_size = 0;
let price_history = [];
let last_action_tick = -1000;
let fomo_triggered = false;

fn on_tick() {
    if !market.trading_enabled { return; }

    if !initialized {
        initialized = true;
        let cash_percent = rng.rand_int(25, 50);
        lot_size = account.cash * cash_percent / 100;
        if lot_size < 1000000 {
            lot_size = 1000000;
        }
    }

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

    if price_history.len() < 5 {
        return;
    }

    let delayed_price = price_history[0];
    let current_price = market.price;
    let price_change_pct = (current_price - delayed_price) * 10000 / delayed_price;
    
    if price_change_pct > 200 && !fomo_triggered {
        fomo_triggered = true;
        let buy_amount = lot_size / current_price;
        if buy_amount > 0 && account.cash >= current_price * buy_amount {
            orders.submit_market_buy(buy_amount);
        }
        return;
    }

    if fomo_triggered && market.tick - last_action_tick > 10 {
        fomo_triggered = false;
    }

    let rand_val = rng.rand_int(0, 99);
    
    if rand_val < 5 {
        let offset_pct = rng.rand_int(10, 50);
        let buy_price = delayed_price * (10000 - offset_pct) / 10000;
        let buy_amount = rng.rand_int(1, lot_size / buy_price);
        if buy_amount > 0 && account.cash >= buy_price * buy_amount {
            orders.submit_limit_buy(buy_price, buy_amount);
            last_action_tick = market.tick;
        }
    } else if rand_val > 95 {
        let offset_pct = rng.rand_int(10, 50);
        let sell_price = delayed_price * (10000 + offset_pct) / 10000;
        let sell_amount = rng.rand_int(1, account.stock);
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
            last_action_tick = market.tick;
        }
    }
}