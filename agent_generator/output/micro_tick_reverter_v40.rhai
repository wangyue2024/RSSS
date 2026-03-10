let initialized = false;
let prev_price = 0;
let price_history = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        prev_price = market.price;
        return;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 { return; }
    
    let current_price = market.price;
    
    if price_history.len() >= 5 {
        let old_price = price_history[0];
        let change = current_price - old_price;
        if change > 0 && (change * 100) / old_price > 2 {
            fomo_triggered = true;
        }
    }
    
    price_history.push(current_price);
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
    
    if fomo_triggered {
        if market.ask_price_0 > 0 {
            let cash_to_use = account.cash * 10 / 100;
            let amount = cash_to_use / market.ask_price_0;
            if amount > 0 {
                orders.submit_market_buy(amount);
            }
        }
        return;
    }
    
    if current_price < prev_price {
        let offset = current_price * 10 / 10000;
        if offset == 0 { offset = 1; }
        let buy_price = current_price - offset;
        let amount = 100;
        if buy_price > 0 {
            orders.submit_limit_buy(buy_price, amount);
        }
    } else if current_price > prev_price {
        let offset = current_price * 10 / 10000;
        if offset == 0 { offset = 1; }
        let sell_price = current_price + offset;
        let amount = 100;
        if account.stock >= amount {
            orders.submit_limit_sell(sell_price, amount);
        }
    }
    
    prev_price = current_price;
}