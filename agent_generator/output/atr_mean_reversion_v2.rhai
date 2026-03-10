let FIXED_AMOUNT = 100;
let initialized = false;
let SESSION_START_CUTOFF = 0;

fn on_tick() {
    if !initialized {
        SESSION_START_CUTOFF = market.total_ticks / 5;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= SESSION_START_CUTOFF {
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let count = my_orders.pending_count();
    let idx = 0;
    while idx < count {
        let oid = my_orders.pending_id(idx);
        orders.submit_cancel(oid);
        idx += 1;
    }
    
    let atr = market.atr_14;
    if atr == 0 { return; }
    
    let ma20 = market.ma_20;
    let current_price = market.price;
    
    let deviation = current_price - ma20;
    let abs_deviation = abs_val(deviation);
    
    let threshold = (atr * 3) / 2;
    
    if abs_deviation > threshold {
        if deviation > 0 {
            if account.stock >= FIXED_AMOUNT {
                orders.submit_limit_sell(ma20, FIXED_AMOUNT);
            }
        } else {
            if account.cash >= ma20 * FIXED_AMOUNT {
                orders.submit_limit_buy(ma20, FIXED_AMOUNT);
            }
        }
    }
}