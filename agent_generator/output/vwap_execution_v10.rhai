let initialized = false;
let total_target = 0;
let panic_threshold = 0;
let init_stock = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        total_target = rng.rand_int(5000, 15000);
        panic_threshold = -rng.rand_int(50000, 200000);
        init_stock = account.stock;
    }
    
    if !market.trading_enabled { return; }
    
    if account.unrealized_pnl < panic_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    let current_bought = account.stock - init_stock;
    if current_bought >= total_target {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let remaining = total_target - current_bought;
    if remaining <= 0 {
        return;
    }
    
    let volume_factor = clamp_val(market.volume, 1000, 100000);
    let slice_size = (remaining * volume_factor) / 500000;
    slice_size = clamp_val(slice_size, 10, remaining);
    
    if slice_size > 0 && market.bid_price_0 > 0 {
        orders.submit_limit_buy(market.bid_price_0, slice_size);
    }
}