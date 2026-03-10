let initialized = false;
let trade_amount = 0;
let order_age_limit = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
        trade_amount = 1000;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= order_age_limit {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if my_orders.pending_count() > 0 {
        return;
    }
    
    let atr = market.atr_14;
    let ma = market.ma_20;
    let price = market.price;
    
    if atr == 0 || ma == 0 {
        return;
    }
    
    let deviation = price - ma;
    let threshold = atr * 15 / 10;
    
    if deviation > threshold && deviation > 0 {
        let limit_price = market.bid_price_0;
        if limit_price > 0 {
            orders.submit_limit_sell(limit_price, trade_amount);
        }
    } else if deviation < -threshold && deviation < 0 {
        let limit_price = market.ask_price_0;
        if limit_price > 0 {
            orders.submit_limit_buy(limit_price, trade_amount);
        }
    }
}