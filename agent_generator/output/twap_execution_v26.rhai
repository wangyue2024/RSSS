let initialized = false;
let target_position = 50_000;
let slice_size = 500;
let slice_interval = 10;
let stop_loss_threshold = 0;
let last_buy_tick = -999_999;
let panic_mode = false;

fn on_tick() {
    if !initialized {
        stop_loss_threshold = -1 * rng.rand_int(100_000, 500_000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if panic_mode {
        return;
    }
    
    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        panic_mode = true;
        return;
    }
    
    if market.tick - last_buy_tick >= slice_interval && account.stock < target_position {
        let remaining = target_position - account.stock;
        let buy_amount = if slice_size < remaining { slice_size } else { remaining };
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
            last_buy_tick = market.tick;
        }
    }
}