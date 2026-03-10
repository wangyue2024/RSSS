let price_buffer = [];
let action_buffer = [];
let buffer_size = 5;
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_buffer.push(market.price);
    if price_buffer.len() > buffer_size {
        price_buffer.remove(0);
    }
    
    if price_buffer.len() >= buffer_size {
        let old_price = price_buffer[0];
        
        let rand_val = rng.rand_int(0, 99);
        
        if rand_val < 5 {
            let offset = rng.rand_int(-1000, 1000);
            let quantity = rng.rand_int(1, 50);
            let bid_price = old_price + offset + 1;
            
            if bid_price > 0 && account.cash >= bid_price * quantity {
                orders.submit_limit_buy(bid_price, quantity);
            }
        } else if rand_val > 95 {
            let offset = rng.rand_int(-1000, 1000);
            let quantity = rng.rand_int(1, 50);
            let ask_price = old_price + offset + 1;
            
            if ask_price > 0 && account.stock >= quantity {
                orders.submit_limit_sell(ask_price, quantity);
            }
        }
    }
}