let initialized = false;
let total_to_sell = 0;
let iceberg_chunk = 0;
let last_order_id = -1;
let order_placed_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        total_to_sell = account.stock * 30 / 100;
        iceberg_chunk = total_to_sell / 100;
        if iceberg_chunk == 0 {
            iceberg_chunk = 1;
        }
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let had_fill = false;
    let fill_count = my_orders.fill_count();
    let i = 0;
    while i < fill_count {
        let fill_side = my_orders.fill_side(i);
        if fill_side == 1 {
            had_fill = true;
            total_to_sell -= my_orders.fill_amount(i);
        }
        i += 1;
    }
    
    let pending_count = my_orders.pending_count();
    i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if had_fill && total_to_sell > 0 {
        let ask_price = market.ask_price_0;
        if ask_price > 0 {
            last_order_id = orders.submit_limit_sell(ask_price, iceberg_chunk);
            order_placed_tick = current_tick;
        }
    } else if last_order_id == -1 && total_to_sell > 0 {
        let ask_price = market.ask_price_0;
        if ask_price > 0 {
            last_order_id = orders.submit_limit_sell(ask_price, iceberg_chunk);
            order_placed_tick = current_tick;
        }
    } else if last_order_id != -1 {
        let order_still_exists = false;
        let pending_count2 = my_orders.pending_count();
        i = 0;
        while i < pending_count2 {
            if my_orders.pending_id(i) == last_order_id {
                order_still_exists = true;
                break;
            }
            i += 1;
        }
        
        if order_still_exists {
            if current_tick - order_placed_tick > 3 {
                orders.submit_cancel(last_order_id);
                last_order_id = -1;
            }
        } else {
            last_order_id = -1;
        }
    }
    
    if total_to_sell <= 0 {
        last_order_id = -1;
    }
}