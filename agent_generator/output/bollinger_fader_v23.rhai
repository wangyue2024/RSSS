let initialized = false;
let trade_amount = 100;
let buy_order_id = 0;
let sell_order_id = 0;
let buy_order_tick = 0;
let sell_order_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        trade_amount = rng.rand_int(80, 120);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let ma20 = market.ma_20;
    let std = market.std_dev;
    
    if ma20 == 0 || std == 0 { return; }
    
    let lower_band = ma20 - 2 * std;
    let upper_band = ma20 + 2 * std;
    
    let old_buy_found = false;
    let old_sell_found = false;
    let active_buy = false;
    let active_sell = false;
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        let placed = my_orders.pending_placed_tick(i);
        
        if current_tick - placed > 3 {
            orders.submit_cancel(oid);
            if oid == buy_order_id { old_buy_found = true; }
            if oid == sell_order_id { old_sell_found = true; }
        } else {
            if oid == buy_order_id { active_buy = true; }
            if oid == sell_order_id { active_sell = true; }
        }
        i += 1;
    }
    
    if old_buy_found || !active_buy {
        buy_order_id = orders.submit_limit_buy(lower_band, trade_amount);
        buy_order_tick = current_tick;
    }
    
    if old_sell_found || !active_sell {
        sell_order_id = orders.submit_limit_sell(upper_band, trade_amount);
        sell_order_tick = current_tick;
    }
}