let initialized = false;
let fomo_triggered = false;
let price_5_ago = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel orders older than 3 ticks
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // FOMO check: price jump > 2% in 5 ticks
    if market.history_len() >= 5 {
        price_5_ago = market.history_price(4);
        let current_price = market.price;
        let jump_threshold = price_5_ago * 200 / 10000;  // 2% of price_5_ago
        if current_price - price_5_ago > jump_threshold {
            fomo_triggered = true;
            let buy_amount = 100;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }
    
    // Reset FOMO if condition no longer holds
    fomo_triggered = false;
    
    // Order flow logic
    if market.buy_volume > 3 * market.sell_volume {
        let target_price = if market.ask_price_0 != 0 { market.ask_price_0 } else { market.price };
        let buy_amount = 100;
        
        // Only place if no pending orders exist
        if my_orders.pending_count() == 0 && buy_amount > 0 {
            orders.submit_limit_buy(target_price, buy_amount);
        }
    }
}