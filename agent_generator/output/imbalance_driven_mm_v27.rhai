let initialized = false;
let lazy_interval = 50;
let max_order_age = 3;
let base_spread = 10_000;
let order_size = 100;
let imbalance_shift_factor = 5_000;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
    }
    
    // High-Frequency Canceler: cancel orders older than max_order_age
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let age = market.tick - my_orders.pending_placed_tick(i);
        if age > max_order_age {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Morning Person: only trade in first 20% of session
    if market.tick * 100 / market.total_ticks >= 20 {
        return;
    }
    
    // Lazy Trader: only act every lazy_interval ticks
    if market.tick % lazy_interval != 0 {
        return;
    }
    
    // Calculate imbalance-driven price shift
    let shift = market.order_imbalance * imbalance_shift_factor / 100;
    let mid_price = market.price + shift;
    
    let bid_price = mid_price - base_spread / 2;
    let ask_price = mid_price + base_spread / 2;
    
    // Cancel any remaining orders before placing new ones
    let remaining_cnt = my_orders.pending_count();
    let j = 0;
    while j < remaining_cnt {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }
    
    // Place new limit orders
    if account.cash >= bid_price * order_size && bid_price > 0 {
        orders.submit_limit_buy(bid_price, order_size);
    }
    
    if account.stock >= order_size && ask_price > 0 {
        orders.submit_limit_sell(ask_price, order_size);
    }
}