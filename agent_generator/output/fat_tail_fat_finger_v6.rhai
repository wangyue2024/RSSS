let initialized = false;
let stop_loss_threshold = 0;
let normal_order_amount = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(10_000_000, 100_000_000);
        normal_order_amount = rng.rand_int(1, 10);
    }
    
    if !market.trading_enabled { return; }
    
    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if market.tick % 50 == 0 {
        let fat_finger_chance = rng.rand_int(0, 9999);
        if fat_finger_chance == 0 {
            let fat_amount = normal_order_amount * 100;
            if rng.rand_bool(50) {
                orders.submit_market_buy(fat_amount);
            } else {
                orders.submit_market_sell(fat_amount);
            }
        }
    }
}