let initialized = false;
let threshold_percent = 50;
let max_order_age = 3;
let order_size = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        threshold_percent = rng.rand_int(30, 80);
        order_size = rng.rand_int(80, 200);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let vwap = market.vwap;
    let price = market.price;
    
    let i = 0;
    while i < my_orders.pending_count() {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > max_order_age {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if my_orders.pending_count() > 0 { return; }
    
    let threshold_value = vwap * threshold_percent / 10000;
    
    if account.stock == 0 {
        if price < vwap - threshold_value {
            orders.submit_limit_buy(price, order_size);
        }
    } else {
        if price >= vwap {
            orders.submit_limit_sell(vwap, account.stock);
        } else {
            if price < vwap - threshold_value {
                orders.submit_limit_buy(price, order_size);
            }
        }
    }
}