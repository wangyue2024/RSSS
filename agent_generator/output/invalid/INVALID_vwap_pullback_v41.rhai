// Generation Failed after 5 retries.
// Last error: Violated NO FLOATS rule. Found floating point numbers like 0.5 or 12.34.
// Global variables persist across ticks
let initialized = false;
let lot_size = 100;
let base_lot_size = 100;
let vwap_threshold = 15000; // 1.5% below VWAP (15000/1000000)
let last_trade_was_loss = false;
let last_avg_cost = 0;
let last_exit_price = 0;
let rounding_factor = 1_000_000;

// Helper function to round to nearest dollar
fn round_price(price) {
    let remainder = price % rounding_factor;
    if remainder >= 500000 {
        price - remainder + rounding_factor
    } else {
        price - remainder
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        // Randomize parameters within reasonable ranges
        base_lot_size = rng.rand_int(50, 200);
        lot_size = base_lot_size;
        vwap_threshold = rng.rand_int(10000, 30000); // 1-3% below VWAP
    }
    
    if !market.trading_enabled { 
        return; 
    }
    
    // Cancel all pending orders each tick
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Check fills from last tick to determine trade outcomes
    let fill_count = my_orders.fill_count();
    let j = 0;
    while j < fill_count {
        let fill_side = my_orders.fill_side(j);
        let fill_price = my_orders.fill_price(j);
        
        if fill_side == 0 { // Buy fill
            // Update average cost tracking
            if account.stock > 0 {
                last_avg_cost = account.avg_cost;
            }
        } else { // Sell fill
            last_exit_price = fill_price;
            
            // Check if last trade was a loss
            if last_avg_cost > 0 && last_exit_price > 0 {
                // Sell price lower than avg cost = loss
                if last_exit_price < last_avg_cost {
                    last_trade_was_loss = true;
                    // Martingale: double lot size on loss
                    lot_size = lot_size * 2;
                    // Cap at reasonable maximum
                    if lot_size > 1000 {
                        lot_size = 1000;
                    }
                } else {
                    last_trade_was_loss = false;
                    // Reset to base lot size on win
                    lot_size = base_lot_size;
                }
            }
            last_avg_cost = 0;
            last_exit_price = 0;
        }
        j += 1;
    }
    
    let current_price = market.price;
    let vwap = market.vwap;
    
    // Calculate threshold price (vwap minus threshold percentage)
    let threshold_price = vwap - (vwap * vwap_threshold / 1_000_000);
    
    // BUY LOGIC: Price significantly below VWAP
    if current_price < threshold_price && account.stock == 0 {
        // Calculate buy price (round to nearest dollar)
        let buy_price = round_price(market.bid_price_0);
        
        // Ensure we have enough cash
        let max_buyable = account.cash / buy_price;
        let buy_amount = max_buyable < lot_size ? max_buyable : lot_size;
        
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
    
    // SELL LOGIC: Price at or above VWAP and we have position
    if account.stock > 0 && current_price >= vwap {
        // Calculate sell price (round to nearest dollar)
        let sell_price = round_price(market.ask_price_0);
        
        // Sell entire position
        orders.submit_limit_sell(sell_price, account.stock);
    }
}