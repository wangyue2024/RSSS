let initialized = false;
let target_position = 50_000;
let slice_size = 500;
let interval_ticks = 10;
let last_order_tick = -9999;
let order_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        order_price = ((market.price + 500_000) / 1_000_000) * 1_000_000;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let total_ticks = market.total_ticks;
    
    if current_tick >= total_ticks / 5 {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_position = account.stock;
    let remaining = target_position - current_position;
    
    if remaining <= 0 { return; }
    
    if current_tick - last_order_tick >= interval_ticks {
        let order_amount = slice_size;
        if remaining < slice_size {
            order_amount = remaining;
        }
        
        let rounded_price = ((market.price + 500_000) / 1_000_000) * 1_000_000;
        
        if order_amount > 0 {
            orders.submit_limit_buy(rounded_price, order_amount);
            last_order_tick = current_tick;
        }
    }
}