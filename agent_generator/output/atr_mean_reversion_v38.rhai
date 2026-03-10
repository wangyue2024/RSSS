let initialized = false;
let trade_size = 100;
let max_order_age = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let atr = market.atr_14;
    let ma = market.ma_20;
    let price = market.price;
    
    let deviation = price - ma;
    let abs_dev = abs_val(deviation);
    let threshold = atr * 3 / 2;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= max_order_age {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if my_orders.pending_count() > 0 {
        return;
    }
    
    if abs_dev > threshold && atr > 0 {
        let target_amount = trade_size;
        if deviation > 0 {
            if market.ask_price_0 > 0 {
                let limit_price = market.ask_price_0 - 1;
                orders.submit_limit_sell(limit_price, target_amount);
            }
        } else {
            if market.bid_price_0 > 0 {
                let limit_price = market.bid_price_0 + 1;
                orders.submit_limit_buy(limit_price, target_amount);
            }
        }
    }
}