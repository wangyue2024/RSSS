let initialized = false;
let target_position = 0;
let slice_size = 0;
let last_action_tick = -1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let total_capital = account.cash + (account.stock * market.price);
        let five_percent_cap = total_capital * 5 / 100;
        let max_slice_shares = five_percent_cap / market.price;
        
        target_position = account.stock + 50_000;
        slice_size = rng.rand_int(1, max_slice_shares);
        if slice_size > 500 {
            slice_size = 500;
        }
    }
    
    if !market.trading_enabled { return; }
    
    let morning_end = market.total_ticks / 5;
    if market.tick >= morning_end { return; }
    
    if (market.tick % 50) != 0 { return; }
    
    let two_percent_of_price = (market.price * 2) / 100;
    if market.std_dev > two_percent_of_price { return; }
    
    let current_position = account.stock;
    let remaining_to_target = target_position - current_position;
    
    if remaining_to_target <= 0 { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let amount_to_buy = slice_size;
    if remaining_to_target < slice_size {
        amount_to_buy = remaining_to_target;
    }
    
    if amount_to_buy > 0 {
        orders.submit_market_buy(amount_to_buy);
        last_action_tick = market.tick;
    }
}