let initialized = false;
let price_history = [];
let fomo_triggered = false;
let fomo_cooldown = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        for i in range(0, 10) {
            price_history.push(market.price);
        }
    }
    
    if !market.trading_enabled { return; }
    
    price_history.remove(0);
    price_history.push(market.price);
    
    if price_history.len() >= 5 {
        let old_price = price_history[0];
        let current_price = price_history[price_history.len() - 1];
        if old_price > 0 {
            let change_pct = (current_price - old_price) * 10000 / old_price;
            if change_pct > 200 && !fomo_triggered {
                fomo_triggered = true;
                fomo_cooldown = 50;
                let buy_amount = rng.rand_int(1, 10);
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                }
                return;
            }
        }
    }
    
    if fomo_triggered {
        fomo_cooldown -= 1;
        if fomo_cooldown <= 0 {
            fomo_triggered = false;
        }
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let rand_val = rng.rand_int(0, 99);
    
    if rand_val < 5 {
        let quantity = rng.rand_int(1, 10);
        let offset = rng.rand_int(-50, 50);
        let price = market.price + offset * 10000;
        if price > 0 && quantity > 0 {
            orders.submit_limit_buy(price, quantity);
        }
    } else if rand_val > 95 {
        let quantity = rng.rand_int(1, 10);
        let offset = rng.rand_int(-50, 50);
        let price = market.price + offset * 10000;
        if price > 0 && quantity > 0 {
            orders.submit_limit_sell(price, quantity);
        }
    }
}