// Global variables persist across ticks
let initialized = false;
let delta = 0;
let order_amount = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        // Initialize parameters with RNG
        delta = rng.rand_int(500, 2000); // price offset in micros
        order_amount = rng.rand_int(100, 500); // shares to trade
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel orders pending for 3+ ticks
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Get price movement
    let current_price = market.price;
    let prev_price = market.history_price(1);
    if current_price == prev_price { return; }
    
    if current_price < prev_price {
        // Price dropped - place limit buy
        let raw_price = current_price - delta;
        // Round to nearest dollar (1_000_000 micros)
        let remainder = raw_price % 1_000_000;
        let rounded = raw_price - remainder;
        if remainder >= 500_000 {
            rounded = rounded + 1_000_000;
        }
        // Add 1 micro to jump ahead
        let final_price = rounded + 1;
        orders.submit_limit_buy(final_price, order_amount);
    } else if current_price > prev_price {
        // Price rose - place limit sell
        let raw_price = current_price + delta;
        // Round to nearest dollar (1_000_000 micros)
        let remainder = raw_price % 1_000_000;
        let rounded = raw_price - remainder;
        if remainder >= 500_000 {
            rounded = rounded + 1_000_000;
        }
        // Subtract 1 micro to jump ahead (more aggressive sell)
        let final_price = rounded - 1;
        orders.submit_limit_sell(final_price, order_amount);
    }
}