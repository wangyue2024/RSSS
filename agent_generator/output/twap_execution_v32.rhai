let initialized = false;
let target_position = 0;
let slice_size = 0;
let ticks_between = 0;
let last_order_tick = -1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        target_position = 50000;
        slice_size = 500;
        ticks_between = 5;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let current_pos = account.stock;
    let pending_buy_amount = 0;
    let count_pending = my_orders.pending_count();
    let j = 0;
    while j < count_pending {
        if my_orders.pending_side(j) == 0 {
            pending_buy_amount += my_orders.pending_remaining(j);
        }
        j += 1;
    }
    
    let effective_position = current_pos + pending_buy_amount;
    let remaining_to_target = target_position - effective_position;
    
    if remaining_to_target <= 0 {
        return;
    }
    
    let cancel_count = my_orders.pending_count();
    let k = 0;
    while k < cancel_count {
        let placed = my_orders.pending_placed_tick(k);
        if market.tick - placed > 3 {
            let oid = my_orders.pending_id(k);
            orders.submit_cancel(oid);
        }
        k += 1;
    }
    
    if market.tick - last_order_tick >= ticks_between && remaining_to_target > 0 {
        let order_amount = slice_size;
        if order_amount > remaining_to_target {
            order_amount = remaining_to_target;
        }
        orders.submit_market_buy(order_amount);
        last_order_tick = market.tick;
    }
}