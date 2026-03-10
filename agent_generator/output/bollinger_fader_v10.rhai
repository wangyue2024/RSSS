let initialized = false;
let panic_threshold = 0;
let trade_amount = 100;

fn on_tick() {
    if (!initialized) {
        panic_threshold = rng.rand_int(10_000, 50_000);
        initialized = true;
    }
    
    if (!market.trading_enabled) { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while (i < pending_cnt) {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if (account.unrealized_pnl < -panic_threshold) {
        if (account.stock > 0) {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    let middle_band = market.ma_20;
    let std = market.std_dev;
    let lower_raw = middle_band - 2 * std;
    let upper_raw = middle_band + 2 * std;
    
    let lower_band = ((lower_raw + 500_000) / 1_000_000) * 1_000_000;
    let upper_band = ((upper_raw + 500_000) / 1_000_000) * 1_000_000;
    
    if (lower_band > 0) {
        orders.submit_limit_buy(lower_band, trade_amount);
    }
    
    if (upper_band > 0) {
        orders.submit_limit_sell(upper_band, trade_amount);
    }
}