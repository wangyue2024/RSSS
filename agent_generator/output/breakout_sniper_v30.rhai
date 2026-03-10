// Global variables persist across ticks
let price_history = [];
let high_20_history = [];
let initialized = false;
let fomo_window = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders each tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Update price history (current tick)
    price_history.push(market.price);
    high_20_history.push(market.high_20);
    fomo_window.push(market.price);
    
    // Keep only necessary history (5 ticks for delay, 3 for FOMO)
    if price_history.len() > 5 {
        price_history.remove(0);
        high_20_history.remove(0);
    }
    if fomo_window.len() > 3 {
        fomo_window.remove(0);
    }
    
    // FOMO check: price jump >2% in 3 ticks (using integer math)
    if fomo_window.len() == 3 {
        let old_price = fomo_window[0];
        let current_price = fomo_window[2];
        if old_price > 0 {
            // 2% = 200/10000 = 1/50
            let jump_threshold = old_price / 50;
            if current_price - old_price > jump_threshold {
                fomo_triggered = true;
                // Market buy with 30% of cash
                let buy_amount = (account.cash * 3000 / 10000) / market.price;
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                }
                return;
            }
        }
    }
    
    // Reset FOMO if no trigger
    fomo_triggered = false;
    
    // Delayed reaction: only use data from 5 ticks ago
    if price_history.len() < 5 || high_20_history.len() < 5 {
        return;
    }
    
    let delayed_price = price_history[0];
    let delayed_high_20 = high_20_history[0];
    
    // Breakout condition (using delayed data)
    if delayed_price > delayed_high_20 {
        // Aggressive buy: use 25% of cash
        let buy_amount = (account.cash * 2500 / 10000) / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    }
    
    // Stubborn holder: only sell at profit using current price (not delayed)
    if account.stock > 0 && market.price > account.avg_cost {
        // Sell 20% of position
        let sell_amount = account.stock * 2000 / 10000;
        if sell_amount > 0 {
            orders.submit_market_sell(sell_amount);
        }
    }
}