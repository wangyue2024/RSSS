// Global variables
let initialized = false;
let ref_price = 0;
let last_update_tick = 0;
let SPREAD = 5000;
let ORDER_AMOUNT = 100;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        SPREAD = rng.rand_int(2000, 10000);
        ORDER_AMOUNT = rng.rand_int(50, 200);
    }
    
    // Delayed reaction: use price from 5 ticks ago
    if market.tick - last_update_tick >= 5 {
        if market.history_len() >= 6 {
            ref_price = market.history_price(5);
            last_update_tick = market.tick;
        }
    }
    
    // Cancel orders older than 3 ticks
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Place new orders if we have a reference price
    if ref_price > 0 {
        // Cancel any remaining orders (in case some weren't caught above)
        let remaining_cnt = my_orders.pending_count();
        let j = 0;
        while j < remaining_cnt {
            let oid = my_orders.pending_id(j);
            orders.submit_cancel(oid);
            j += 1;
        }
        
        // Place symmetric limit orders
        let buy_price = ref_price - SPREAD;
        let sell_price = ref_price + SPREAD;
        
        if buy_price > 0 {
            orders.submit_limit_buy(buy_price, ORDER_AMOUNT);
        }
        orders.submit_limit_sell(sell_price, ORDER_AMOUNT);
    }
}