let initialized = false;
let price_memory = [];
let current_order_id = 0;
let total_to_sell = 100000;
let remaining_to_sell = total_to_sell;
let slice_size = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        slice_size = rng.rand_int(50, 200);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    price_memory.push(market.price);
    if price_memory.len() > 5 {
        price_memory.remove(0);
    }
    
    if price_memory.len() < 5 {
        return;
    }
    
    let delayed_price = price_memory[0];
    
    let pending_count = my_orders.pending_count();
    let has_active_order = false;
    let i = 0;
    while i < pending_count {
        if my_orders.pending_id(i) == current_order_id {
            has_active_order = true;
            break;
        }
        i += 1;
    }
    
    let fill_count = my_orders.fill_count();
    i = 0;
    while i < fill_count {
        let fill_id = my_orders.fill_id(i);
        if fill_id == current_order_id {
            remaining_to_sell = remaining_to_sell - my_orders.fill_amount(i);
            has_active_order = false;
        }
        i += 1;
    }
    
    if !has_active_order && remaining_to_sell > 0 {
        let order_amount = slice_size;
        if remaining_to_sell < slice_size {
            order_amount = remaining_to_sell;
        }
        
        current_order_id = orders.submit_limit_sell(delayed_price, order_amount);
    }
}