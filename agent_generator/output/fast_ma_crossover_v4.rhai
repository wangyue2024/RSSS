// Global variables persist across ticks automatically
let initialized = false;
let base_lot_size = 10000;
let current_lot_size = base_lot_size;
let last_trade_profit = true;
let ma5_buffer = [];
let ma20_buffer = [];
let price_buffer = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        // Initialize parameters
        base_lot_size = 10000;
        current_lot_size = base_lot_size;
        last_trade_profit = true;
        ma5_buffer.clear();
        ma20_buffer.clear();
        price_buffer.clear();
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all current pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Store current values for delayed reaction
    ma5_buffer.push(market.ma_5);
    ma20_buffer.push(market.ma_20);
    price_buffer.push(market.price);
    
    // Keep only last 6 ticks (0-5, where 0 is 5 ticks old)
    if ma5_buffer.len() > 6 {
        ma5_buffer.remove(0);
        ma20_buffer.remove(0);
        price_buffer.remove(0);
    }
    
    // Need at least 6 ticks of history to have 5-tick old data
    if ma5_buffer.len() < 6 {
        return;
    }
    
    // Use 5-tick old data (index 0 in our buffer)
    let delayed_ma5 = ma5_buffer[0];
    let delayed_ma20 = ma20_buffer[0];
    let delayed_price = price_buffer[0];
    
    // Calculate previous 5-tick old values (from previous iteration)
    let prev_delayed_ma5 = ma5_buffer[1];
    let prev_delayed_ma20 = ma20_buffer[1];
    
    // Check for crossover using delayed data
    let ma5_crossed_above = prev_delayed_ma5 <= prev_delayed_ma20 && delayed_ma5 > delayed_ma20;
    let ma5_crossed_below = prev_delayed_ma5 >= prev_delayed_ma20 && delayed_ma5 < delayed_ma20;
    
    // Martingale sizing: double lot size if last trade was a loss
    if !last_trade_profit {
        current_lot_size = current_lot_size * 2;
        // Cap the lot size to avoid overflow
        if current_lot_size > 1000000 {
            current_lot_size = 1000000;
        }
    } else {
        current_lot_size = base_lot_size;
    }
    
    // Buy signal: MA5 crosses above MA20 (using delayed data)
    if ma5_crossed_above {
        orders.submit_market_buy(current_lot_size);
        // Reset for next trade evaluation
        last_trade_profit = true;
    }
    
    // Sell signal: MA5 crosses below MA20 AND price is above avg cost (diamond hands)
    if ma5_crossed_below && delayed_price > account.avg_cost && account.stock > 0 {
        // Calculate if this trade would be profitable
        let would_be_profit = delayed_price > account.avg_cost;
        orders.submit_market_sell(account.stock);
        // Update last trade result for martingale
        last_trade_profit = would_be_profit;
    }
}