let initialized = false;
let target_position = 50000;
let base_lot_size = 500;
let current_lot_size = base_lot_size;
let last_avg_cost = 0;
let loss_detected = false;
let tick_counter = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_avg_cost = account.avg_cost;
    }
    
    if !market.trading_enabled { return; }
    
    tick_counter += 1;
    
    if tick_counter % 50 != 0 {
        return;
    }
    
    if account.stock >= target_position {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    if last_avg_cost > 0 && market.price < last_avg_cost {
        loss_detected = true;
    }
    
    if loss_detected {
        current_lot_size = current_lot_size * 2;
        loss_detected = false;
    } else {
        current_lot_size = base_lot_size;
    }
    
    let remaining = target_position - account.stock;
    let order_amount = if current_lot_size > remaining { remaining } else { current_lot_size };
    
    if order_amount > 0 {
        let bid_price = if market.bid_price_0 > 0 { market.bid_price_0 } else { market.price - 1000 };
        let limit_price = bid_price + 1;
        orders.submit_limit_buy(limit_price, order_amount);
    }
    
    last_avg_cost = account.avg_cost;
}