let initialized = false;
let iceberg_total = 0;
let remaining_iceberg = 0;
let last_order_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        iceberg_total = account.stock * 70 / 100;
        remaining_iceberg = iceberg_total;
    }
    
    if !market.trading_enabled { return; }
    
    let morning_active = market.tick < market.total_ticks / 5;
    
    if !morning_active {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    if remaining_iceberg <= 0 {
        return;
    }
    
    let check_fills = my_orders.fill_count();
    let i = 0;
    while i < check_fills {
        let fill_side = my_orders.fill_side(i);
        if fill_side == 1 {
            let fill_amount = my_orders.fill_amount(i);
            remaining_iceberg -= fill_amount;
        }
        i += 1;
    }
    
    let pending_count = my_orders.pending_count();
    let cancel_needed = false;
    
    if pending_count > 0 {
        let current_tick = market.tick;
        let order_age = current_tick - my_orders.pending_placed_tick(0);
        if order_age >= 3 {
            cancel_needed = true;
        }
    }
    
    if cancel_needed || pending_count == 0 {
        if pending_count > 0 {
            let oid = my_orders.pending_id(0);
            orders.submit_cancel(oid);
        }
        
        if market.ask_price_0 > 0 && market.ask_price_0 > account.avg_cost {
            let slice_size = iceberg_total * 1 / 100;
            if slice_size < 1 { slice_size = 1; }
            if slice_size > remaining_iceberg { slice_size = remaining_iceberg; }
            
            orders.submit_limit_sell(market.ask_price_0, slice_size);
            last_order_tick = market.tick;
        }
    }
}