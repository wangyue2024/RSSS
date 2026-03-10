// Global variables persist across ticks
let initialized = false;
let base_lot_size = 100;
let current_lot_size = 100;
let last_trade_was_loss = false;
let slope_history = [];
let prev_slope = 0;
let last_realized_pnl = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = 100;
        current_lot_size = base_lot_size;
        last_trade_was_loss = false;
        slope_history = [];
        prev_slope = 0;
        last_realized_pnl = account.realized_pnl;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Update martingale sizing based on realized PnL changes
    let current_realized_pnl = account.realized_pnl;
    let pnl_change = current_realized_pnl - last_realized_pnl;
    
    if pnl_change < 0 {
        // Last trade was a loss
        if !last_trade_was_loss {
            // First consecutive loss
            current_lot_size = base_lot_size * 2;
        } else {
            // Consecutive loss - double again (capped at 8x base)
            current_lot_size = current_lot_size * 2;
            if current_lot_size > base_lot_size * 8 {
                current_lot_size = base_lot_size * 8;
            }
        }
        last_trade_was_loss = true;
    } else if pnl_change > 0 {
        // Last trade was profitable - reset to base size
        current_lot_size = base_lot_size;
        last_trade_was_loss = false;
    }
    
    last_realized_pnl = current_realized_pnl;
    
    // Calculate price slope using recent history (last 10 ticks)
    let lookback = 10;
    if market.history_len() >= lookback {
        let price_array = [];
        let idx = 0;
        while idx < lookback {
            price_array.push(market.history_price(idx));
            idx += 1;
        }
        
        let current_slope = arr_slope(price_array);
        
        // Store slope in history (keep last 3)
        slope_history.push(current_slope);
        if slope_history.len() > 3 {
            slope_history.remove(0);
        }
        
        // Calculate slope acceleration (if we have enough history)
        let slope_acceleration = 0;
        if slope_history.len() >= 2 {
            let old_slope = slope_history[0];
            let new_slope = slope_history[slope_history.len() - 1];
            slope_acceleration = new_slope - old_slope;
        }
        
        // Buy condition: positive slope AND acceleration AND not already holding
        if current_slope > 100 && slope_acceleration > 50 && account.stock == 0 {
            let buy_amount = current_lot_size;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
        
        // Panic sell condition: negative slope AND holding position
        if current_slope < -50 && account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        
        prev_slope = current_slope;
    }
}