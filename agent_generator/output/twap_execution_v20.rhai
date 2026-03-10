let initialized = false;
let target_position = 50000;
let slice_size = 500;
let execution_interval = 10;
let tick_counter = 0;
let total_bought = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        target_position = rng.rand_int(30000, 70000);
        slice_size = rng.rand_int(200, 800);
        execution_interval = rng.rand_int(5, 20);
    }
    
    if !market.trading_enabled { return; }
    
    tick_counter += 1;
    
    if tick_counter >= execution_interval && total_bought < target_position {
        tick_counter = 0;
        
        let remaining_to_buy = target_position - total_bought;
        let buy_amount = if slice_size < remaining_to_buy { slice_size } else { remaining_to_buy };
        
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
            total_bought += buy_amount;
        }
    }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
}