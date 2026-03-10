let initialized = false;
let sell_amount = 0;
let base_volume = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        sell_amount = 1000;
        base_volume = 50000;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick % 50 != 0 { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let price_above_ma = market.price > market.ma_60 && market.ma_60 != 0;
    let volume_drop = market.volume * 10 < base_volume;
    
    if price_above_ma && volume_drop && account.stock >= sell_amount {
        orders.submit_limit_sell(market.price, sell_amount);
    }
}