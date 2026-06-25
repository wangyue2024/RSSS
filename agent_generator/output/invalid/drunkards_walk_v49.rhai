let initialized = false;
let price_buffer = [];
let decision_delay = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Store current price
    price_buffer.push(market.price);
    if price_buffer.len() > decision_delay {
        price_buffer.remove(0);
    }
    
    // Only act if we have enough delayed data
    if price_buffer.len() < decision_delay {
        return;
    }
    
    let delayed_price = price_buffer[0];
    
    // Generate random decision
    let rand_val = rng.rand_int(0, 99);
    
    if rand_val < 5 {
        // Random buy
        let cash_to_use = (account.cash * rng.rand_int(25, 50)) / 100;
        let amount = cash_to_use / delayed_price;
        if amount < 1 {
            amount = 1;
        }
        
        let price_offset = rng.rand_int(-50000, 50000); // -5% to +5%
        let target_price = delayed_price + (delayed_price * price_offset) / 1000000;
        if target_price < 1 {
            target_price = 1;
        }
        
        orders.submit_limit_buy(target_price, amount);
    } else if rand_val > 95 {
        // Random sell
        let max_sell = account.stock;
        if max_sell > 0 {
            let amount = (max_sell * rng.rand_int(25, 100)) / 100;
            if amount < 1 {
                amount = 1;
            }
            
            let price_offset = rng.rand_int(-50000, 50000);
            let target_price = delayed_price + (delayed_price * price_offset) / 1000000;
            if target_price < 1 {
                target_price = 1;
            }
            
            orders.submit_limit_sell(target_price, amount);
        }
    }
}