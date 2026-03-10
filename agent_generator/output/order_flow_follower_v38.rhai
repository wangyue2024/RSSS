let initialized = false;
let order_amount = 0;
let active_order_id = -1;
let order_placed_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        order_amount = 100;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 {
        return;
    }
    
    if active_order_id != -1 {
        let current_tick = market.tick;
        if current_tick - order_placed_tick > 3 {
            orders.submit_cancel(active_order_id);
            active_order_id = -1;
            order_placed_tick = 0;
        }
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        if oid != active_order_id {
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if active_order_id == -1 && market.buy_volume > 3 * market.sell_volume {
        if market.ask_price_0 > 0 {
            orders.submit_limit_buy(market.ask_price_0, order_amount);
            active_order_id = my_orders.pending_id(0);
            order_placed_tick = market.tick;
        }
    }
}