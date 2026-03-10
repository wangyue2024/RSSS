// Global variables
let morning_active = false;
let morning_ticks = 0;

fn on_tick() {
    // Check if market is open
    if !market.trading_enabled { return; }
    
    // Morning person check: only first 20% of session
    if market.tick < (market.total_ticks * 20 / 100) {
        morning_active = true;
    } else {
        morning_active = false;
        return;
    }
    
    // Order flow condition: buy_volume > 3 * sell_volume
    if market.buy_volume > (3 * market.sell_volume) {
        // Cancel any existing orders
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        // Buy 100 shares with market order
        orders.submit_market_buy(100);
    }
}