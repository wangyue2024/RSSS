let initialized = false;
let my_order_id = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let i = 0;
    let pending = my_orders.pending_count();
    while i < pending {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if my_orders.pending_count() > 0 { return; }
    
    let deviation = abs_val(market.price - market.ma_20);
    let threshold = (market.atr_14 * 3) / 2;
    
    if deviation > threshold {
        if market.price > market.ma_20 {
            let limit_price = market.ma_20 + market.atr_14;
            orders.submit_limit_sell(limit_price, 100);
        } else {
            let limit_price = market.ma_20 - market.atr_14;
            orders.submit_limit_buy(limit_price, 100);
        }
    }
}