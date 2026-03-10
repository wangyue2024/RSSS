// Global variables
let price_history = [];
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Morning Person: only trade in first 20% of session
    if market.tick >= market.total_ticks / 5 {
        return;
    }
    
    // Update price history for FOMO check (keep last 10 ticks)
    price_history.push(market.price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    // Cancel all pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // FOMO check: price jumped >2% in last 10 ticks
    let fomo_triggered = false;
    if price_history.len() == 10 {
        let old_price = price_history[0];
        if old_price > 0 {
            let change = abs_val(market.price - old_price);
            let threshold = (old_price * 2) / 100;  // 2% threshold
            if change > threshold {
                // Market buy immediately
                let amount = 100;
                orders.submit_market_buy(amount);
                fomo_triggered = true;
            }
        }
    }
    
    // Core order flow strategy (only if FOMO not triggered)
    if !fomo_triggered {
        // Check buy_volume vs sell_volume (3x ratio)
        if market.buy_volume > 3 * market.sell_volume && market.sell_volume > 0 {
            // Join the crowd: market buy
            let amount = 100;
            orders.submit_market_buy(amount);
        }
    }
    
    // Stubborn Holder: only sell if price > avg_cost
    if account.stock > 0 && market.price > account.avg_cost {
        // Sell half of holdings at current price
        let sell_amount = account.stock / 2;
        if sell_amount > 0 {
            orders.submit_limit_sell(market.price, sell_amount);
        }
    }
}