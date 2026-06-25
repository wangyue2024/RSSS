let initialized = false;
let target_sell_amount = 0;
let iceberg_slice = 0;
let remaining_to_sell = 0;
let last_order_tick = 0;
let current_order_id = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        target_sell_amount = 50000;
        iceberg_slice = 100;
        remaining_to_sell = target_sell_amount;
    }
    
    if !market.trading_enabled { return; }
    
    // Check for fills in the last tick
    let fill_cnt = my_orders.fill_count();
    let i = 0;
    while i < fill_cnt {
        let fill_id = my_orders.fill_id(i);
        if fill_id == current_order_id {
            let filled_qty = my_orders.fill_amount(i);
            remaining_to_sell = remaining_to_sell - filled_qty;
            if remaining_to_sell < 0 {
                remaining_to_sell = 0;
            }
            
            // Replenish the order immediately after fill
            if remaining_to_sell > 0 {
                let cancel_success = orders.submit_cancel(current_order_id);
                current_order_id = 0;
                last_order_tick = 0;
            }
        }
        i += 1;
    }
    
    // Cancel old orders (impatient - 3 tick timeout)
    if current_order_id != 0 {
        let pending_cnt = my_orders.pending_count();
        let found = false;
        let j = 0;
        while j < pending_cnt {
            if my_orders.pending_id(j) == current_order_id {
                found = true;
                let age = market.tick - last_order_tick;
                if age >= 3 {
                    orders.submit_cancel(current_order_id);
                    current_order_id = 0;
                    last_order_tick = 0;
                }
                break;
            }
            j += 1;
        }
        if !found {
            current_order_id = 0;
            last_order_tick = 0;
        }
    }
    
    // Place new iceberg order if needed
    if current_order_id == 0 && remaining_to_sell > 0 {
        if market.ask_price_0 > 0 {
            // Off-by-One Pumper: add 1 micro to calculated bid price
            let calculated_bid = market.bid_price_0;
            let sell_price = calculated_bid + 1;
            
            let order_qty = if iceberg_slice < remaining_to_sell {
                iceberg_slice
            } else {
                remaining_to_sell
            };
            
            if order_qty > 0 {
                orders.submit_limit_sell(sell_price, order_qty);
                
                // We need to capture the order ID - in this simulation,
                // we assume the last pending order is ours
                let pending_cnt = my_orders.pending_count();
                if pending_cnt > 0 {
                    current_order_id = my_orders.pending_id(pending_cnt - 1);
                    last_order_tick = market.tick;
                }
            }
        }
    }
}