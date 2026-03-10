let initialized = false;
let target_position = 50_000;
let slice_size = 500;
let interval_ticks = 10;
let stop_threshold = 0;
let panic_mode = false;
let last_buy_tick = -9999;
let total_bought = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_threshold = -rng.rand_int(50_000_000, 200_000_000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if panic_mode {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    if account.unrealized_pnl < stop_threshold {
        panic_mode = true;
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    if account.stock >= target_position {
        return;
    }
    
    if market.tick - last_buy_tick >= interval_ticks {
        let remaining = target_position - account.stock;
        let buy_amount = slice_size;
        if remaining < slice_size {
            buy_amount = remaining;
        }
        
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
            total_bought += buy_amount;
            last_buy_tick = market.tick;
        }
    }
}