let initialized = false;
let fair_value = 0;
let price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_history.len() < 5 {
        return;
    }
    
    let delayed_price = price_history[0];
    
    if delayed_price < fair_value * 95 / 100 && delayed_price >= 1 {
        if delayed_price < fair_value * 90 / 100 {
            let max_buy = account.cash / delayed_price;
            let buy_amount = clamp_val(max_buy / 4, 10, 1000);
            if buy_amount > 0 {
                orders.submit_limit_buy(delayed_price, buy_amount);
            }
        } else {
            let max_buy = account.cash / delayed_price;
            let buy_amount = clamp_val(max_buy / 10, 1, 100);
            if buy_amount > 0 {
                orders.submit_limit_buy(delayed_price, buy_amount);
            }
        }
    }
}