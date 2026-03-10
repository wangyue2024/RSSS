let initialized = false;
let stop_loss_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(10000, 100000);
    }
    
    if !market.trading_enabled { return; }
    
    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if rng.rand_int(0, 9999) == 0 {
        let fat_amount = 10000;
        if rng.rand_bool(50) {
            orders.submit_market_buy(fat_amount);
        } else {
            orders.submit_market_sell(fat_amount);
        }
        return;
    }
    
    if market.tick % 50 == 0 {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
    }
}