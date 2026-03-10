let initialized = false;
let total_to_sell = 0;
let remaining_to_sell = 0;
let iceberg_chunk = 0;
let current_order_id = -1;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        total_to_sell = account.stock * 80 / 100;
        remaining_to_sell = total_to_sell;
        iceberg_chunk = total_to_sell / 200;
        if iceberg_chunk < 100 {
            iceberg_chunk = 100;
        }
    }
    
    if market.tick >= market.total_ticks * 20 / 100 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        current_order_id = -1;
        return;
    }
    
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let i = 0;
        while i < fill_cnt {
            if my_orders.fill_side(i) == 1 && (current_order_id == -1 || my_orders.fill_id(i) == current_order_id) {
                remaining_to_sell -= my_orders.fill_amount(i);
                current_order_id = -1;
            }
            i += 1;
        }
    }
    
    if current_order_id == -1 && remaining_to_sell > 0 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        let order_size = iceberg_chunk;
        if order_size > remaining_to_sell {
            order_size = remaining_to_sell;
        }
        
        if market.ask_price_0 > 0 {
            orders.submit_limit_sell(market.ask_price_0, order_size);
            
            let pending = my_orders.pending_count();
            if pending > 0 {
                current_order_id = my_orders.pending_id(0);
            }
        }
    }
}