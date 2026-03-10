let initialized = false;
let base_spread = 2000;
let order_size = 1000;
let sensitivity = 50;
let pending_ticks = [];

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    if market.tick >= market.total_ticks / 5 { return; }
    
    let current_tick = market.tick;
    let imbalance = market.order_imbalance;
    
    let mid_price = market.price;
    let imbalance_shift = imbalance * sensitivity / 1000;
    let adjusted_mid = mid_price + imbalance_shift;
    
    let bid_price = adjusted_mid - base_spread / 2 + 1;
    let ask_price = adjusted_mid + base_spread / 2;
    
    let i = 0;
    while i < my_orders.pending_count() {
        let oid = my_orders.pending_id(i);
        let placed_tick = my_orders.pending_placed_tick(i);
        
        if current_tick - placed_tick > 3 {
            orders.submit_cancel(oid);
            
            let j = 0;
            while j < pending_ticks.len() {
                if pending_ticks[j] == oid {
                    pending_ticks.remove(j);
                    break;
                }
                j += 1;
            }
        }
        i += 1;
    }
    
    let bid_amount = order_size;
    if bid_amount > 0 && account.cash >= bid_price * bid_amount {
        orders.submit_limit_buy(bid_price, bid_amount);
        pending_ticks.push(my_orders.pending_id(my_orders.pending_count() - 1));
    }
    
    let ask_amount = order_size;
    if ask_amount > 0 && account.stock >= ask_amount {
        orders.submit_limit_sell(ask_price, ask_amount);
        pending_ticks.push(my_orders.pending_id(my_orders.pending_count() - 1));
    }
}