let initialized = false;
let trade_amount = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled {
        return;
    }
    
    let current_tick = market.tick;
    
    let i = 0;
    while i < my_orders.pending_count() {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let ma20 = market.ma_20;
    let stddev = market.std_dev;
    
    let lower_band = ma20 - 2 * stddev;
    let upper_band = ma20 + 2 * stddev;
    
    let has_buy = false;
    let has_sell = false;
    
    let pending_cnt = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt {
        let side = my_orders.pending_side(j);
        if side == 0 {
            has_buy = true;
        } else {
            has_sell = true;
        }
        j += 1;
    }
    
    if !has_buy {
        orders.submit_limit_buy(lower_band, trade_amount);
    }
    
    if !has_sell {
        orders.submit_limit_sell(upper_band, trade_amount);
    }
}