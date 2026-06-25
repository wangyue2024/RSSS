let SCALING_FACTOR = 1_000_000;
let initialized = false;
let iceberg_target = 0;
let display_size = 0;
let current_order_id = 0;
let order_placed_tick = 0;
let total_sold = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        
        let risk_averse_threshold = market.price * 100 / SCALING_FACTOR;
        if market.std_dev > risk_averse_threshold {
            return;
        }
        
        let max_lot = account.total_equity * 5 / 100;
        display_size = rng.rand_int(1_000, max_lot / 10);
        
        iceberg_target = account.stock * 90 / 100;
        if iceberg_target < display_size {
            iceberg_target = display_size;
        }
    }
    
    if iceberg_target <= total_sold {
        return;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        if oid != current_order_id {
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let found_current = false;
    let j = 0;
    while j < pending_count {
        if my_orders.pending_id(j) == current_order_id {
            found_current = true;
            let age = market.tick - order_placed_tick;
            if age >= 3 {
                orders.submit_cancel(current_order_id);
                current_order_id = 0;
                found_current = false;
            }
            break;
        }
        j += 1;
    }
    
    let fill_count = my_orders.fill_count();
    let k = 0;
    while k < fill_count {
        let fill_id = my_orders.fill_id(k);
        if fill_id == current_order_id {
            total_sold += my_orders.fill_amount(k);
            current_order_id = 0;
            found_current = false;
            break;
        }
        k += 1;
    }
    
    if !found_current && current_order_id == 0 {
        if market.ask_price_0 > 0 {
            let remaining = iceberg_target - total_sold;
            let order_amount = display_size;
            if order_amount > remaining {
                order_amount = remaining;
            }
            
            if order_amount > 0 {
                current_order_id = orders.submit_limit_sell(market.ask_price_0, order_amount);
                order_placed_tick = market.tick;
            }
        }
    }
}