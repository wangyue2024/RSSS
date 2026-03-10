let initialized = false;
let target_position = 50_000;
let slice_size = 500;
let interval_ticks = 10;
let last_execution_tick = 0;
let cumulative_bought = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        if rng.rand_bool(50) {
            interval_ticks = 5;
        }
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    if cumulative_bought >= target_position { return; }
    
    if (current_tick - last_execution_tick) >= interval_ticks {
        let remaining = target_position - cumulative_bought;
        let order_amount = if slice_size < remaining { slice_size } else { remaining };
        
        if order_amount > 0 {
            let bid_price = market.bid_price_0;
            if bid_price > 0 {
                let my_bid = bid_price + 1;
                orders.submit_limit_buy(my_bid, order_amount);
            } else {
                orders.submit_market_buy(order_amount);
            }
            cumulative_bought += order_amount;
            last_execution_tick = current_tick;
        }
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
}