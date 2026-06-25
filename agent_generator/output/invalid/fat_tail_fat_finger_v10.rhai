let initialized = false;
let price_history = [];
let last_tick_action = -1000;
let normal_size = 10000;
let fat_finger_chance = 1;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    price_history.push(market.price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if current_tick - last_tick_action < 10 {
        return;
    }
    
    if price_history.len() >= 5 {
        let current_price = market.price;
        let old_price = price_history[price_history.len() - 5];
        
        if old_price != 0 {
            let change_bp = (current_price - old_price) * 10000 / old_price;
            
            if change_bp > 200 || change_bp < -200 {
                let buy_amount = normal_size;
                if account.cash > buy_amount * current_price {
                    orders.submit_market_buy(buy_amount);
                    last_tick_action = current_tick;
                    return;
                }
            }
        }
    }
    
    let r = rng.rand_int(0, 9999);
    if r < fat_finger_chance {
        let fat_amount = normal_size * 100;
        if rng.rand_bool(50) {
            if account.cash > fat_amount * market.price {
                orders.submit_market_buy(fat_amount);
            }
        } else {
            if account.stock > fat_amount {
                orders.submit_market_sell(fat_amount);
            }
        }
        last_tick_action = current_tick;
        return;
    }
    
    if price_history.len() >= 6 {
        let delayed_price = price_history[price_history.len() - 6];
        let spread = market.ask_price_0 - market.bid_price_0;
        
        if spread > 0 && spread < 100000 {
            let my_bid = delayed_price + 1;
            if my_bid < market.ask_price_0 && account.cash > normal_size * my_bid {
                orders.submit_limit_buy(my_bid, normal_size);
                last_tick_action = current_tick;
            }
        }
    }
}