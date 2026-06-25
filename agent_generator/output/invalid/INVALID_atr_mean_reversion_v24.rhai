// Generation Failed after 5 retries.
// Last error: Violated NO FLOATS rule. Found floating point numbers like 0.5 or 12.34.
let initialized = false;
let trade_amount = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        trade_amount = 1000;
    }
    
    if !market.trading_enabled { return; }
    
    // Morning Person constraint: only trade during first 20% of session
    if market.tick >= market.total_ticks * 20 / 100 {
        // Cancel all orders when session progresses beyond 20%
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }
    
    // Cancel all pending orders each tick
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    // Calculate deviation threshold (1.5 * ATR)
    let atr = market.atr_14;
    let threshold = atr * 3 / 2;
    
    // Current price deviation from MA_20
    let deviation = abs_val(market.price - market.ma_20);
    
    // Only trade if deviation exceeds threshold
    if deviation > threshold && threshold > 0 {
        // Price above MA_20: overbought -> sell signal
        if market.price > market.ma_20 {
            // Stubborn Holder constraint: only sell at profit
            if market.price > account.avg_cost && account.stock >= trade_amount {
                orders.submit_limit_sell(market.price, trade_amount);
            }
        } 
        // Price below MA_20: oversold -> buy signal  
        else if market.price < market.ma_20 {
            // Calculate affordable shares
            let max_affordable = account.cash / market.price;
            if max_affordable >= trade_amount {
                orders.submit_limit_buy(market.price, trade_amount);
            }
        }
    }
}