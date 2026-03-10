// Global variables persist across ticks
let initialized = false;
let fomo_window = 5;
let inventory_threshold = 1000;
let base_spread = 50_000;
let order_size = 100;
let round_base = 1_000_000;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders that are older than 3 ticks
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_at = my_orders.pending_placed_tick(i);
        if market.tick - placed_at > 3 {
            orders.submit_cancel(my_orders.pending_id(i));
        }
        i += 1;
    }
    
    // FOMO check: price jump > 2% in last fomo_window ticks
    let fomo_triggered = false;
    if market.history_len() >= fomo_window {
        let past_price = market.history_price(market.history_len() - fomo_window);
        if past_price > 0 {
            // Calculate 2% threshold using integer math
            let threshold = past_price * 2 / 100;
            if market.price > past_price + threshold {
                fomo_triggered = true;
                // Market buy immediately
                orders.submit_market_buy(order_size);
            }
        }
    }
    
    // If FOMO triggered, skip rest of strategy
    if fomo_triggered { return; }
    
    // Calculate mid price from order book
    let mid_price = market.price;
    if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    }
    
    // Inventory-based skew
    let inventory = account.stock;
    let buy_spread = base_spread;
    let sell_spread = base_spread;
    
    if inventory > inventory_threshold {
        // High inventory: sell closer, buy further away
        buy_spread = base_spread * 3 / 2;
        sell_spread = base_spread / 2;
    } else if inventory <= 0 {
        // Low/negative inventory: buy closer, sell further away
        buy_spread = base_spread / 2;
        sell_spread = base_spread * 3 / 2;
    }
    
    // Calculate order prices
    let buy_price = mid_price - buy_spread;
    let sell_price = mid_price + sell_spread;
    
    // Round to nearest dollar (1,000,000 micros)
    buy_price = ((buy_price + round_base / 2) / round_base) * round_base;
    sell_price = ((sell_price + round_base / 2) / round_base) * round_base;
    
    // Ensure minimum price of 1
    if buy_price < 1 { buy_price = 1; }
    if sell_price < 1 { sell_price = 1; }
    
    // Place limit orders
    orders.submit_limit_buy(buy_price, order_size);
    orders.submit_limit_sell(sell_price, order_size);
}