// Global variables
let initialized = false;
let buy_threshold_micros = 0;
let fixed_position_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        buy_threshold_micros = rng.rand_int(5000, 20000);
        fixed_position_size = rng.rand_int(10, 50);
    }
    
    if !market.trading_enabled { return; }
    
    // Morning Person: Only trade in first 20% of session
    if market.tick >= market.total_ticks / 5 {
        return;
    }
    
    // Cancel all pending orders
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    let vwap = market.vwap;
    let avg_cost = account.avg_cost;
    let stock_held = account.stock;
    
    // Buy condition: price significantly below VWAP
    if current_price < vwap - buy_threshold_micros && stock_held == 0 {
        // Off-by-One Pumper: add 1 micro to calculated bid
        let bid_price = current_price + 1;
        orders.submit_limit_buy(bid_price, fixed_position_size);
    }
    
    // Sell condition: price above VWAP AND strictly above avg_cost (Stubborn Holder)
    if stock_held > 0 && current_price > vwap && current_price > avg_cost {
        orders.submit_limit_sell(current_price, stock_held);
    }
}