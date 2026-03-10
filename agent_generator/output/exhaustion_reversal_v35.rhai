let initialized = false;
let lot_size_percent = 0;
let prev_volume = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size_percent = rng.rand_int(25, 50);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_volume = market.volume;
    let volume_drop_threshold = prev_volume * 10 / 100;
    let exhaustion_signal = market.high_20 > market.ma_60 && current_volume < volume_drop_threshold;
    
    if exhaustion_signal {
        let trade_value = account.cash * lot_size_percent / 100;
        let amount = trade_value / market.price;
        
        if amount > 0 {
            orders.submit_market_sell(amount);
        }
    }
    
    prev_volume = current_volume;
}