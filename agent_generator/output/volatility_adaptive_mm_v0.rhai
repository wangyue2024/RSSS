let initialized = false;
let price_buffer = [];
let std_dev_buffer = [];
let order_amount = 1000;
let base_spread = 5000;
let vol_factor = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
        // No RNG needed for this strategy
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all existing orders each tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Store current data in buffers
    price_buffer.push(market.price);
    std_dev_buffer.push(market.std_dev);
    
    // Keep only last 6 ticks (0-5)
    if price_buffer.len() > 6 {
        price_buffer.remove(0);
    }
    if std_dev_buffer.len() > 6 {
        std_dev_buffer.remove(0);
    }
    
    // Need at least 5 old ticks + current = 6 elements
    if price_buffer.len() < 6 { return; }
    if std_dev_buffer.len() < 6 { return; }
    
    // Use data from 5 ticks ago (index 0 in our buffer)
    let delayed_price = price_buffer[0];
    let delayed_std_dev = std_dev_buffer[0];
    
    // Calculate spread: base + vol_factor * std_dev
    let spread_addition = delayed_std_dev * vol_factor;
    let total_spread = base_spread + spread_addition;
    
    // Calculate bid/ask prices (half spread each side)
    let half_spread = total_spread / 2;
    let bid_price = delayed_price - half_spread;
    let ask_price = delayed_price + half_spread;
    
    // Place orders
    orders.submit_limit_buy(bid_price, order_amount);
    orders.submit_limit_sell(ask_price, order_amount);
}