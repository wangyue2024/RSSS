let initialized = false;
let stop_loss_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(100_000, 1_000_000);
    }
    
    if !market.trading_enabled { return; }
    if market.tick * 5 >= market.total_ticks { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let rand_val = rng.rand_int(0, 99);
    
    if rand_val < 5 {
        let qty = rng.rand_int(1, 100);
        let use_limit = rng.rand_bool(50);
        
        if use_limit {
            let offset = rng.rand_int(-200_000, 200_000);
            let raw_price = market.price + offset;
            let rounded_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
            orders.submit_limit_buy(rounded_price, qty);
        } else {
            orders.submit_market_buy(qty);
        }
    } else if rand_val > 95 {
        let qty = rng.rand_int(1, 100);
        let use_limit = rng.rand_bool(50);
        
        if use_limit {
            let offset = rng.rand_int(-200_000, 200_000);
            let raw_price = market.price + offset;
            let rounded_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
            orders.submit_limit_sell(rounded_price, qty);
        } else {
            orders.submit_market_sell(qty);
        }
    }
}