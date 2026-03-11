let initialized = false;
let fair_value = 0;
let price_history = [];

fn on_tick() {
    if !initialized {
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() < 5 {
        return;
    }
    
    let delayed_price = price_history[0];
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if delayed_price < fair_value {
        let buy_amount = 0;
        
        if delayed_price < fair_value * 90 / 100 {
            buy_amount = 50;
        } else if delayed_price < fair_value * 95 / 100 {
            buy_amount = 10;
        }
        
        if buy_amount > 0 && account.cash > delayed_price * buy_amount {
            orders.submit_limit_buy(delayed_price, buy_amount);
        }
    }
}