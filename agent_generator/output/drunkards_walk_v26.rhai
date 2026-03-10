let initialized = false;
let lot_size = 0;
let fomo_window = 5;
let price_history = [];

fn on_tick() {
    if !initialized {
        let max_shares = (account.total_equity * 5 / 100) / market.price;
        if max_shares > 0 {
            lot_size = rng.rand_int(1, max_shares);
        } else {
            lot_size = 1;
        }
        initialized = true;
    }
    
    if !market.trading_enabled {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    price_history.push(current_price);
    if price_history.len() > fomo_window {
        price_history.remove(0);
    }
    
    let fomo_triggered = false;
    if price_history.len() >= 2 {
        let oldest_price = price_history[0];
        let price_change = (current_price - oldest_price) * 10000 / oldest_price;
        if price_change > 200 {
            fomo_triggered = true;
            let buy_amount = rng.rand_int(1, lot_size);
            if buy_amount > 0 && account.cash > current_price * buy_amount {
                orders.submit_market_buy(buy_amount);
            }
        }
    }
    
    let std_dev_threshold = current_price * 200 / 10000;
    if market.std_dev > std_dev_threshold && !fomo_triggered {
        return;
    }
    
    if fomo_triggered {
        return;
    }
    
    let roll = rng.rand_int(0, 99);
    if roll < 5 {
        let amount = rng.rand_int(1, lot_size);
        let offset = rng.rand_int(-100, 100);
        let limit_price = current_price + (current_price * offset) / 10000;
        if limit_price < 1 {
            limit_price = 1;
        }
        if amount > 0 && account.cash > limit_price * amount {
            orders.submit_limit_buy(limit_price, amount);
        }
    } else if roll > 95 {
        let amount = rng.rand_int(1, lot_size);
        let offset = rng.rand_int(-100, 100);
        let limit_price = current_price + (current_price * offset) / 10000;
        if limit_price < 1 {
            limit_price = 1;
        }
        if amount > 0 && account.stock >= amount {
            orders.submit_limit_sell(limit_price, amount);
        }
    }
}