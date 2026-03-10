let initialized = false;
let price_history = [];
let hist_max_len = 5;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
    }
    
    let current_price = market.price;
    price_history.push(current_price);
    if price_history.len() > hist_max_len {
        price_history.remove(0);
    }
    
    let fomo_triggered = false;
    if price_history.len() == hist_max_len {
        let past_price = price_history[0];
        let change = current_price - past_price;
        let change_percent = change * 100 / past_price;
        if change_percent > 2 {
            let buy_amount = rng.rand_int(1, 1000);
            orders.submit_market_buy(buy_amount);
            fomo_triggered = true;
        }
    }
    
    if fomo_triggered { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.tick % 50 != 0 { return; }
    
    let rand_val = rng.rand_int(0, 99);
    
    if rand_val < 5 {
        let qty = rng.rand_int(1, 1000);
        let offset = rng.rand_int(-1000, 1000);
        let base_price = if market.bid_price_0 != 0 { market.bid_price_0 } else { market.price };
        let price = base_price + offset + 1;
        orders.submit_limit_buy(price, qty);
    }
    
    if rand_val > 95 {
        let qty = rng.rand_int(1, 1000);
        let offset = rng.rand_int(-1000, 1000);
        let base_price = if market.ask_price_0 != 0 { market.ask_price_0 } else { market.price };
        let price = base_price + offset;
        orders.submit_limit_sell(price, qty);
    }
}