// Global variables
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Lazy trader: only evaluate every 50 ticks
    if market.tick % 50 != 0 { return; }
    
    // Cancel all pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let buy_vol = market.buy_volume;
    let sell_vol = market.sell_volume;
    
    // Check if buy volume is 3x larger than sell volume (using integer math)
    if buy_vol > 3 * sell_vol && sell_vol > 0 {
        // Join the crowd with a market buy
        let amount = 100; // Fixed amount in shares
        orders.submit_market_buy(amount);
    }
}