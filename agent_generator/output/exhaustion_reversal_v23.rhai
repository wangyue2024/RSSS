let initialized = false;
let exhaustion_threshold = 0;
let pending_order_ticks = [];
let pending_order_ids = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        exhaustion_threshold = rng.rand_int(100_000, 500_000);
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel orders older than 3 ticks
    let i = 0;
    while i < pending_order_ids.len() {
        let placed_tick = pending_order_ticks[i];
        if market.tick - placed_tick >= 3 {
            let oid = pending_order_ids[i];
            orders.submit_cancel(oid);
            pending_order_ids.remove(i);
            pending_order_ticks.remove(i);
        } else {
            i += 1;
        }
    }
    
    // Update pending orders tracking (remove filled/cancelled orders)
    i = 0;
    while i < pending_order_ids.len() {
        let oid = pending_order_ids[i];
        let found = false;
        let pending_count = my_orders.pending_count();
        let j = 0;
        while j < pending_count {
            if my_orders.pending_id(j) == oid {
                found = true;
                break;
            }
            j += 1;
        }
        if !found {
            pending_order_ids.remove(i);
            pending_order_ticks.remove(i);
        } else {
            i += 1;
        }
    }
    
    // Exhaustion detection: price above MA60 with very low volume
    let price_above_ma = market.price > market.ma_60;
    let volume_near_zero = market.volume < exhaustion_threshold;
    
    if price_above_ma && volume_near_zero {
        // Only sell if we have stock AND can sell at profit
        if account.stock > 0 && market.price > account.avg_cost {
            // Cancel any existing pending orders
            let count = my_orders.pending_count();
            let j = 0;
            while j < count {
                let oid = my_orders.pending_id(j);
                orders.submit_cancel(oid);
                j += 1;
            }
            
            // Submit limit sell order
            let sell_price = market.bid_price_0;
            let sell_amount = account.stock;
            if sell_price > 0 && sell_amount > 0 {
                orders.submit_limit_sell(sell_price, sell_amount);
                
                // Track this new order
                pending_order_ids.push(my_orders.pending_id(0));
                pending_order_ticks.push(market.tick);
            }
        }
    }
}