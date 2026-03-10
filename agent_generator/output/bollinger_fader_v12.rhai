// Global variables for delayed data buffer
let price_history = [];
let ma20_history = [];
let std_dev_history = [];
let history_ready = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders at start of tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Append current data to history buffers
    price_history.push(market.price);
    ma20_history.push(market.ma_20);
    std_dev_history.push(market.std_dev);
    
    // Keep only last 5 ticks
    while price_history.len() > 5 {
        price_history.remove(0);
        ma20_history.remove(0);
        std_dev_history.remove(0);
    }
    
    // Check if we have 5 ticks of delayed data
    if price_history.len() == 5 {
        history_ready = true;
    }
    
    // Only trade with 5-tick delayed data
    if !history_ready { return; }
    
    // Use data from 5 ticks ago (first element in buffer)
    let delayed_ma20 = ma20_history[0];
    let delayed_std = std_dev_history[0];
    
    // Calculate Bollinger Bands with 2 standard deviations
    let upper_band = delayed_ma20 + 2 * delayed_std;
    let lower_band = delayed_ma20 - 2 * delayed_std;
    
    // Fixed order size of 100 shares
    let order_amount = 100;
    
    // Place limit buy at lower band if we have cash
    if account.cash > lower_band * order_amount {
        orders.submit_limit_buy(lower_band, order_amount);
    }
    
    // Place limit sell at upper band if we have stock
    if account.stock >= order_amount {
        orders.submit_limit_sell(upper_band, order_amount);
    }
}