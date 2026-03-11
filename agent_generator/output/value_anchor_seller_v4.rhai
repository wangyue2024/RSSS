let initialized = false;
let fair_value = 0;
let last_action_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let base_fair = 100 * 1_000_000;
        let random_offset = rng.rand_int(-5_000_000, 5_000_000);
        fair_value = base_fair + random_offset;
        last_action_tick = market.tick;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed = my_orders.pending_placed_tick(i);
        if current_tick - placed >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if (current_tick - last_action_tick) < 50 {
        return;
    }
    last_action_tick = current_tick;
    
    let current_price = market.price;
    
    let aggressive_threshold = fair_value * 110 / 100;
    let small_threshold = fair_value * 105 / 100;
    
    if current_price > fair_value && account.stock > 0 {
        let sell_amount;
        if current_price > aggressive_threshold {
            sell_amount = account.stock * 10 / 100;
        } else if current_price > small_threshold {
            sell_amount = account.stock * 2 / 100;
        } else {
            return;
        }
        
        if sell_amount < 1 {
            sell_amount = 1;
        }
        
        orders.submit_limit_sell(current_price, sell_amount);
    }
}