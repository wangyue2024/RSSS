let initialized = false;
let buy_order_age = 0;
let sell_order_age = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let pending_count = my_orders.pending_count();
    
    // Cancel orders older than 3 ticks
    let i = 0;
    while i < pending_count {
        let placed = my_orders.pending_placed_tick(i);
        if current_tick - placed >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Check order flow condition for buying
    if market.buy_volume > 3 * market.sell_volume {
        // Check if we already have a pending buy order
        let has_pending_buy = false;
        let j = 0;
        while j < my_orders.pending_count() {
            if my_orders.pending_side(j) == 0 {
                has_pending_buy = true;
                break;
            }
            j += 1;
        }
        
        if !has_pending_buy {
            // Place limit buy order at current price
            let buy_price = market.price;
            let buy_amount = 100; // Fixed amount
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
    
    // Selling condition: only if price > avg_cost AND we have stock
    if account.stock > 0 && market.price > account.avg_cost {
        // Check if we already have a pending sell order
        let has_pending_sell = false;
        let k = 0;
        while k < my_orders.pending_count() {
            if my_orders.pending_side(k) == 1 {
                has_pending_sell = true;
                break;
            }
            k += 1;
        }
        
        if !has_pending_sell {
            // Place limit sell order at current price
            let sell_price = market.price;
            let sell_amount = account.stock;
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}