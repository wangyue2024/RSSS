let initialized = false;
let target_position = 0;
let slice_size = 0;
let interval_ticks = 0;
let next_trade_tick = 0;
let volatility_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let max_position_cost = account.total_equity * 5 / 100;
        let max_slice_shares = max_position_cost / market.price;
        
        if max_slice_shares > 0 {
            slice_size = rng.rand_int(1, max_slice_shares);
        } else {
            slice_size = 1;
        }
        
        target_position = 50000;
        interval_ticks = rng.rand_int(5, 20);
        next_trade_tick = market.tick + interval_ticks;
        volatility_threshold = market.price * 5 / 100;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.std_dev > volatility_threshold { return; }
    
    if account.stock >= target_position { return; }
    
    if market.tick >= next_trade_tick {
        let remaining = target_position - account.stock;
        let trade_amount = if remaining < slice_size { remaining } else { slice_size };
        
        if trade_amount > 0 {
            orders.submit_market_buy(trade_amount);
        }
        
        next_trade_tick = market.tick + interval_ticks;
    }
}