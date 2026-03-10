let target_position = 50_000;
let base_lot_size = 500;
let order_interval = 10;
let impatience_ticks = 3;

let initialized = false;
let ticks_since_last_order = 0;
let current_lot_size = 0;
let pending_order_id = -1;
let order_placed_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        current_lot_size = base_lot_size;
        ticks_since_last_order = 0;
        pending_order_id = -1;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel any pending order that's been waiting too long
    if pending_order_id != -1 {
        // Find the order in pending orders
        let found = false;
        let i = 0;
        while i < my_orders.pending_count() {
            if my_orders.pending_id(i) == pending_order_id {
                found = true;
                if market.tick - my_orders.pending_placed_tick(i) >= impatience_ticks {
                    orders.submit_cancel(pending_order_id);
                    pending_order_id = -1;
                }
                break;
            }
            i += 1;
        }
        if !found {
            pending_order_id = -1;
        }
    }
    
    // Martingale sizing: check if last trade was a loss
    let last_fill_count = my_orders.fill_count();
    if last_fill_count > 0 {
        // Check the most recent fill
        let last_fill_side = my_orders.fill_side(last_fill_count - 1);
        if last_fill_side == 0 { // Buy side
            let last_fill_price = my_orders.fill_price(last_fill_count - 1);
            if market.price < last_fill_price {
                // Last buy was at higher price -> loss, double lot size
                current_lot_size = current_lot_size * 2;
            } else {
                // Last buy was profitable, reset to base
                current_lot_size = base_lot_size;
            }
        }
    }
    
    // Check if we need to place a new order
    if pending_order_id == -1 {
        ticks_since_last_order += 1;
        
        if ticks_since_last_order >= order_interval {
            let current_position = account.stock;
            if current_position < target_position {
                let remaining = target_position - current_position;
                let order_amount = current_lot_size;
                if order_amount > remaining {
                    order_amount = remaining;
                }
                
                if order_amount > 0 {
                    // Calculate rounded price (nearest 1_000_000 micros)
                    let rounded_price = ((market.price + 500_000) / 1_000_000) * 1_000_000;
                    
                    let new_order_id = orders.submit_limit_buy(rounded_price, order_amount);
                    pending_order_id = new_order_id;
                    order_placed_tick = market.tick;
                    ticks_since_last_order = 0;
                }
            }
        }
    }
}