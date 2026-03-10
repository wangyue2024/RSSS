let initialized = false;
let panic_threshold = 0;
let prev_ma_5 = 0;
let prev_ma_20 = 0;
let fixed_amount = 100;

fn on_tick() {
    if !initialized {
        panic_threshold = -rng.rand_int(10000, 50000);
        prev_ma_5 = market.ma_5;
        prev_ma_20 = market.ma_20;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let cancel_infos = [];
    let i = 0;
    while i < my_orders.pending_count() {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            let remaining = my_orders.pending_remaining(i);
            let side = my_orders.pending_side(i);
            cancel_infos.push([oid, remaining, side]);
        }
        i += 1;
    }
    
    for info in cancel_infos {
        let oid = info[0];
        let remaining = info[1];
        let side = info[2];
        orders.submit_cancel(oid);
        if remaining > 0 && side == 0 {
            orders.submit_market_buy(remaining);
        }
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        
        let i = 0;
        while i < my_orders.pending_count() {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let golden_cross = false;
    let death_cross = false;
    
    if market.ma_5 > market.ma_20 && prev_ma_5 <= prev_ma_20 {
        golden_cross = true;
    }
    
    if market.ma_5 < market.ma_20 && prev_ma_5 >= prev_ma_20 {
        death_cross = true;
    }
    
    if death_cross && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        
        let i = 0;
        while i < my_orders.pending_count() {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
    }
    
    if golden_cross && my_orders.pending_count() == 0 && account.stock == 0 {
        orders.submit_limit_buy(market.price, fixed_amount);
    }
    
    prev_ma_5 = market.ma_5;
    prev_ma_20 = market.ma_20;
}