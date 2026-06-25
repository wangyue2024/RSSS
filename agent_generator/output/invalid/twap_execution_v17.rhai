let initialized = false;
let target_position = 50_000;
let slice_size = 500;
let tick_interval = 10;
let last_buy_tick = 0;
let price_history = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_buy_tick = market.tick;
    }
    
    if !market.trading_enabled { return; }
    
    // Update price history for FOMO detection
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    // FOMO detection: price jumps >2% in last 5 ticks
    if price_history.len() >= 5 && !fomo_triggered {
        let old_price = price_history[0];
        let new_price = price_history[price_history.len() - 1];
        if old_price > 0 && new_price > 0 {
            // Check if price increased by more than 2% using integer math
            if new_price * 100 > old_price * 102 {
                fomo_triggered = true;
                // Cancel all pending orders
                let pending_count = my_orders.pending_count();
                let i = 0;
                while i < pending_count {
                    let oid = my_orders.pending_id(i);
                    orders.submit_cancel(oid);
                    i += 1;
                }
                // Market buy remaining target immediately
                let current_stock = account.stock;
                if current_stock < target_position {
                    let buy_amount = target_position - current_stock;
                    if buy_amount > 0 {
                        orders.submit_market_buy(buy_amount);
                    }
                }
                return;
            }
        }
    }
    
    if fomo_triggered {
        return;
    }
    
    // Cancel limit orders older than 3 ticks
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // TWAP execution logic
    let current_stock = account.stock;
    
    if current_stock < target_position && market.tick - last_buy_tick >= tick_interval {
        // Calculate slice to buy
        let remaining = target_position - current_stock;
        let buy_amount = if slice_size < remaining { slice_size } else { remaining };
        
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
            last_buy_tick = market.tick;
        }
    }
}