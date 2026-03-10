let initialized = false;
let pending_order_id = 0;
let pending_order_placed_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    if pending_order_id != 0 {
        let found = false;
        let i = 0;
        while i < my_orders.pending_count() {
            if my_orders.pending_id(i) == pending_order_id {
                found = true;
                break;
            }
            i += 1;
        }
        
        if found {
            if current_tick - pending_order_placed_tick >= 3 {
                orders.submit_cancel(pending_order_id);
                pending_order_id = 0;
            }
        } else {
            pending_order_id = 0;
        }
    }
    
    if current_tick % 50 != 0 { return; }
    
    if pending_order_id != 0 { return; }
    
    let ma5 = market.ma_5;
    let ma20 = market.ma_20;
    
    if ma5 > ma20 && account.stock == 0 {
        orders.submit_market_buy(1000);
        pending_order_id = 0;
        pending_order_placed_tick = 0;
    } else if ma5 < ma20 && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        pending_order_id = 0;
        pending_order_placed_tick = 0;
    }
}