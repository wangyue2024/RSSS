let initialized = false;
let base_spread = 2000;
let max_spread = 20000;
let order_amount = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Morning person: only trade in first 20% of session
    if market.tick >= market.total_ticks * 20 / 100 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }
    
    // Cancel existing orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    // Calculate adaptive spread based on volatility
    let volatility = market.std_dev;
    let vol_factor = clamp_val(volatility / 10000, 100, 500);
    let spread = clamp_val(base_spread * vol_factor / 100, base_spread, max_spread);
    let half_spread = spread / 2;
    
    // Get current mid price
    let bid_price = market.bid_price_0;
    let ask_price = market.ask_price_0;
    let mid_price;
    
    if bid_price > 0 && ask_price > 0 {
        mid_price = (bid_price + ask_price) / 2;
    } else {
        mid_price = market.price;
    }
    
    // Place limit orders
    let my_bid = mid_price - half_spread;
    let my_ask = mid_price + half_spread;
    
    if my_bid > 0 {
        orders.submit_limit_buy(my_bid, order_amount);
    }
    
    if my_ask > 0 {
        orders.submit_limit_sell(my_ask, order_amount);
    }
}