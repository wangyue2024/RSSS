let initialized = false;
let target_position = 50000;
let slice_size = 500;
let interval_ticks = 10;
let last_order_tick = -999999;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_position = account.stock;
    
    if current_position >= target_position {
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
    
    if market.tick >= last_order_tick + interval_ticks {
        last_order_tick = market.tick;
        let remaining_needed = target_position - current_position;
        let order_amount = if slice_size < remaining_needed { slice_size } else { remaining_needed };
        
        if order_amount > 0 {
            orders.submit_market_buy(order_amount);
        }
    }
}