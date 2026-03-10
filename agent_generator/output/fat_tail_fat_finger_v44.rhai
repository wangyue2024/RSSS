let initialized = false;
let base_amount = 100;
let fomo_triggered = false;
let last_eval_tick = 0;
let price_history = [];
let fomo_window = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_amount = rng.rand_int(50, 200);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    price_history.push(market.price);
    if price_history.len() > fomo_window {
        price_history.remove(0);
    }
    
    if price_history.len() == fomo_window {
        let oldest_price = price_history[0];
        let change_bp = (market.price - oldest_price) * 10000 / oldest_price;
        if change_bp > 200 || change_bp < -200 {
            fomo_triggered = true;
        }
    }
    
    if fomo_triggered {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        orders.submit_market_buy(base_amount);
        fomo_triggered = false;
        return;
    }
    
    if current_tick % 50 != 0 && current_tick != 0 {
        return;
    }
    
    last_eval_tick = current_tick;
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fat_finger_roll = rng.rand_int(0, 9999);
    if fat_finger_roll == 0 {
        let side_roll = rng.rand_bool(50);
        let fat_amount = base_amount * 100;
        if side_roll {
            orders.submit_market_buy(fat_amount);
        } else {
            orders.submit_market_sell(fat_amount);
        }
        return;
    }
    
    if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        let spread = market.ask_price_0 - market.bid_price_0;
        let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
        let my_bid = market.bid_price_0 + 1;
        let my_ask = market.ask_price_0 - 1;
        
        if spread > mid_price * 10 / 10000 {
            orders.submit_limit_buy(my_bid, base_amount);
            orders.submit_limit_sell(my_ask, base_amount);
        }
    }
}