// Generation Failed after 5 retries.
// Last error: Violated NO FLOATS rule. Found floating point numbers like 0.5 or 12.34.
let initialized = false;
let last_run_tick = -1;
let recent_prices = [];
let fomo_triggered = false;
let base_spread = 5000; // 0.5% in micros (5/1000)
let imbalance_threshold = 1000;
let quote_amount = 100;

fn on_tick() {
    if !market.trading_enabled { return; }

    // Update price history for FOMO check
    if recent_prices.len() >= 5 {
        recent_prices.remove(0);
    }
    recent_prices.push(market.price);

    // Check FOMO condition every tick
    if recent_prices.len() == 5 {
        let oldest_price = recent_prices[0];
        let current_price = recent_prices[4];
        // Check for 2% increase: current > oldest * 102 / 100
        if current_price * 100 > oldest_price * 102 {
            fomo_triggered = true;
            // Market buy immediately
            let buy_qty = quote_amount * 5;
            if account.cash > buy_qty * market.price {
                orders.submit_market_buy(buy_qty);
            }
            return;
        }
    }

    // Lazy trader: only run main logic every 50 ticks
    if market.tick % 50 != 0 && !initialized {
        return;
    }

    // Cancel all existing orders before new placement
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    if fomo_triggered {
        fomo_triggered = false;
        return;
    }

    // Main market making logic
    let imbalance = market.order_imbalance;
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    
    // Adjust mid price based on imbalance
    let adjusted_mid = mid_price + (imbalance * 10);
    
    // Calculate spread
    let spread = base_spread;
    if imbalance > imbalance_threshold {
        // Positive imbalance - shift prices up
        adjusted_mid += imbalance * 5;
    } else if imbalance < -imbalance_threshold {
        // Negative imbalance - shift prices down
        adjusted_mid += imbalance * 5;
    }
    
    // Calculate bid and ask prices
    let bid_price = adjusted_mid - spread;
    let ask_price = adjusted_mid + spread;
    
    // Place limit orders
    if bid_price > 0 && account.cash > bid_price * quote_amount {
        orders.submit_limit_buy(bid_price, quote_amount);
    }
    
    if ask_price > 0 && account.stock >= quote_amount {
        orders.submit_limit_sell(ask_price, quote_amount);
    }

    last_run_tick = market.tick;
    if !initialized {
        initialized = true;
    }
}