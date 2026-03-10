let initialized = false;
let panic_threshold = 0;
let order_amount = 100;

fn on_tick() {
    if !initialized {
        panic_threshold = -rng.rand_int(10_000, 50_000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    let upper_band = market.ma_20 + 2 * market.std_dev;
    let lower_band = market.ma_20 - 2 * market.std_dev;
    
    if account.cash >= lower_band * order_amount && lower_band > 0 {
        orders.submit_limit_buy(lower_band, order_amount);
    }
    
    if account.stock >= order_amount {
        orders.submit_limit_sell(upper_band, order_amount);
    }
}