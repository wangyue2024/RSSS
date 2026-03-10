let target_position = 50000;
let slice_size = 500;
let frequency_ticks = 10;
let last_order_tick = -1000;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Morning Person: only trade in first 20% of session
    if market.tick >= market.total_ticks * 20 / 100 {
        return;
    }
    
    // Check if we need more stock
    if account.stock >= target_position {
        return;
    }
    
    // Submit order at regular intervals
    if market.tick - last_order_tick >= frequency_ticks {
        let remaining_to_buy = target_position - account.stock;
        let buy_amount = if slice_size < remaining_to_buy { slice_size } else { remaining_to_buy };
        
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
            last_order_tick = market.tick;
        }
    }
}