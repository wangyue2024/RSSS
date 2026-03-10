let initialized = false;
let price_history = [];
let current_order_id = -1;
let total_to_sell = 0;
let iceberg_size = 0;
let remaining_to_sell = 0;
let sell_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        total_to_sell = rng.rand_int(100_000, 500_000);
        iceberg_size = rng.rand_int(100, 500);
        remaining_to_sell = total_to_sell;
    }
    
    if !market.trading_enabled { return; }
    
    // Store current price in history
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    // Use data from 5 ticks ago (delayed reaction)
    if price_history.len() < 5 {
        return;
    }
    let delayed_price = price_history[0];
    
    // Check if our current order was filled
    let fill_count = my_orders.fill_count();
    let was_filled = false;
    let i = 0;
    while i < fill_count {
        if my_orders.fill_id(i) == current_order_id {
            was_filled = true;
            let fill_amount = my_orders.fill_amount(i);
            remaining_to_sell = remaining_to_sell - fill_amount;
            break;
        }
        i += 1;
    }
    
    // Cancel existing order if we need to replace it
    if current_order_id != -1 {
        let order_still_pending = false;
        let pending_count = my_orders.pending_count();
        let j = 0;
        while j < pending_count {
            if my_orders.pending_id(j) == current_order_id {
                order_still_pending = true;
                break;
            }
            j += 1;
        }
        
        if !order_still_pending || was_filled {
            if order_still_pending {
                orders.submit_cancel(current_order_id);
            }
            current_order_id = -1;
        }
    }
    
    // Place new iceberg order if needed
    if current_order_id == -1 && remaining_to_sell > 0 {
        let order_amount = iceberg_size;
        if order_amount > remaining_to_sell {
            order_amount = remaining_to_sell;
        }
        
        // Use best ask price from delayed data (we don't have orderbook history,
        // so use current best ask as approximation for the strategy)
        sell_price = market.ask_price_0;
        if sell_price == 0 {
            // Fallback to delayed price with small premium
            sell_price = delayed_price + 1_000;
        }
        
        current_order_id = orders.submit_limit_sell(sell_price, order_amount);
    }
}