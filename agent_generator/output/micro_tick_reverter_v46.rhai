let initialized = false;
let lot_size = 0;
let last_decision_price = 0;
let price_buffer = [];
let decision_buffer = [];
let pending_order_placed_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let five_percent_capital = account.total_equity * 5 / 100;
        if five_percent_capital > 0 {
            lot_size = rng.rand_int(1, five_percent_capital / 1000);
        } else {
            lot_size = 100;
        }
        
        if lot_size <= 0 {
            lot_size = 100;
        }
    }
    
    if !market.trading_enabled { return; }
    
    price_buffer.push(market.price);
    if price_buffer.len() > 6 {
        price_buffer.remove(0);
    }
    
    let std_dev_threshold = market.price * 2 / 100;
    if market.std_dev > std_dev_threshold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if price_buffer.len() < 6 {
        return;
    }
    
    let price_5_ago = price_buffer[0];
    let price_4_ago = price_buffer[1];
    
    if decision_buffer.len() >= 5 {
        let delayed_decision = decision_buffer.remove(0);
        
        if my_orders.pending_count() == 0 {
            if delayed_decision == 1 {
                let limit_price = market.price * 998 / 1000;
                if account.cash >= limit_price * lot_size {
                    orders.submit_limit_buy(limit_price, lot_size);
                    pending_order_placed_tick = market.tick;
                }
            } else if delayed_decision == -1 {
                let limit_price = market.price * 1002 / 1000;
                if account.stock >= lot_size {
                    orders.submit_limit_sell(limit_price, lot_size);
                    pending_order_placed_tick = market.tick;
                }
            }
        }
    }
    
    let current_decision = 0;
    if price_4_ago < price_5_ago {
        current_decision = 1;
    } else if price_4_ago > price_5_ago {
        current_decision = -1;
    }
    
    decision_buffer.push(current_decision);
    if decision_buffer.len() > 5 {
        decision_buffer.remove(0);
    }
}