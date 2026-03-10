let initialized = false;
let prev_stock = 0;
let last_avg_cost = 0;
let lot_size = 1000;
let base_lot = 1000;
let pending_tp_id = -1;
let pending_sl_id = -1;
let last_action_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(500, 5000);
        lot_size = base_lot;
        last_action_tick = market.tick;
    }
    
    if !market.trading_enabled { return; }
    
    // Lazy trader - only evaluate every 50 ticks
    if (market.tick - last_action_tick) < 50 {
        return;
    }
    
    let current_stock = account.stock;
    
    // Cancel existing orders if position changed
    if prev_stock == 0 && current_stock > 0 {
        if pending_tp_id != -1 {
            orders.submit_cancel(pending_tp_id);
            pending_tp_id = -1;
        }
        if pending_sl_id != -1 {
            orders.submit_cancel(pending_sl_id);
            pending_sl_id = -1;
        }
    }
    
    // Exit logic - check if position closed
    if prev_stock > 0 && current_stock == 0 {
        // Martingale sizing: if last trade was a loss
        if market.price < last_avg_cost {
            lot_size = lot_size * 2;
        } else {
            lot_size = base_lot;
        }
    }
    
    prev_stock = current_stock;
    last_action_tick = market.tick;
    
    // If we have no position, try to enter randomly
    if current_stock == 0 {
        // Cancel any remaining pending orders
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        pending_tp_id = -1;
        pending_sl_id = -1;
        
        // Random entry (1% chance per evaluation)
        if rng.rand_bool(1) {
            // Market buy entry
            let buy_amount = lot_size;
            if account.cash >= market.price * buy_amount {
                orders.submit_market_buy(buy_amount);
                last_avg_cost = account.avg_cost;
                
                // Calculate take-profit price (5% above, plus 1 micro for off-by-one)
                let tp_price = last_avg_cost * 105 / 100 + 1;
                pending_tp_id = orders.submit_limit_sell(tp_price, current_stock);
            }
        }
    }
    
    // If we have position, manage exit orders
    if current_stock > 0 {
        // Only place stop-loss if not already placed
        if pending_sl_id == -1 {
            // Calculate stop-loss trigger (2% below)
            let sl_trigger = last_avg_cost * 98 / 100;
            
            // Check if current price hits stop-loss
            if market.price <= sl_trigger {
                pending_sl_id = orders.submit_market_sell(current_stock);
            }
        }
        
        // Check if take-profit still pending, if not, position closed
        if pending_tp_id != -1 {
            let found = false;
            let pending_count = my_orders.pending_count();
            let i = 0;
            while i < pending_count {
                if my_orders.pending_id(i) == pending_tp_id {
                    found = true;
                    break;
                }
                i += 1;
            }
            if !found {
                pending_tp_id = -1;
            }
        }
    }
}