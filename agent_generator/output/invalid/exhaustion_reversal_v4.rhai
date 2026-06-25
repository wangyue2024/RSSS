let initialized = false;
let last_action_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_action_tick = market.tick;
    }
    
    if !market.trading_enabled { return; }
    
    let tick = market.tick;
    
    if tick % 50 != 0 { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.history_len() < 60 { return; }
    
    let current_price = market.price;
    let current_volume = market.volume;
    let ma_60 = market.ma_60;
    
    if current_price > ma_60 && current_volume < 1000 {
        if account.stock > 0 {
            let sell_amount = account.stock / 2;
            if sell_amount > 0 {
                let bid_price = market.bid_price_0 + 1;
                if bid_price > 0 {
                    orders.submit_limit_sell(bid_price, sell_amount);
                }
            }
        }
    }
}