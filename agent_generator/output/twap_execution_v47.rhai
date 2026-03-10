let initialized = false;
let target_position = 0;
let slice_size = 0;
let interval_ticks = 0;
let last_action_tick = -1000;

fn on_tick() {
    if !initialized {
        target_position = 50000;
        slice_size = 500;
        interval_ticks = 10;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if account.stock >= target_position {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }
    
    if market.tick - last_action_tick >= interval_ticks {
        last_action_tick = market.tick;
        
        let cash_available = account.cash;
        let max_affordable = cash_available / market.price;
        let remaining = target_position - account.stock;
        
        let order_amount = slice_size;
        if order_amount > remaining {
            order_amount = remaining;
        }
        if order_amount > max_affordable {
            order_amount = max_affordable;
        }
        
        if order_amount > 0 {
            let round_base = 1_000_000;
            let raw_price = market.price;
            let rounded = (raw_price + round_base / 2) / round_base * round_base;
            let bid_price = rounded + 1;
            
            orders.submit_limit_buy(bid_price, order_amount);
        }
    }
}