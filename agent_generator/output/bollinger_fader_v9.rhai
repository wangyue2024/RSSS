let initialized = false;
let tick_counter = 0;
let delayed_prices = [];
let delayed_ma_20 = [];
let delayed_std_dev = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        delayed_prices = [];
        delayed_ma_20 = [];
        delayed_std_dev = [];
    }
    
    if !market.trading_enabled {
        return;
    }
    
    // Store current data
    delayed_prices.push(market.price);
    delayed_ma_20.push(market.ma_20);
    delayed_std_dev.push(market.std_dev);
    
    // Keep only last 5 ticks
    while delayed_prices.len() > 5 {
        delayed_prices.remove(0);
    }
    while delayed_ma_20.len() > 5 {
        delayed_ma_20.remove(0);
    }
    while delayed_std_dev.len() > 5 {
        delayed_std_dev.remove(0);
    }
    
    // Only react when we have 5 ticks of history
    if delayed_prices.len() < 5 {
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
    
    // Calculate bands using data from 5 ticks ago
    let old_ma_20 = delayed_ma_20[0];
    let old_std_dev = delayed_std_dev[0];
    let band_width = 2;
    
    let lower_band = old_ma_20 - band_width * old_std_dev;
    let upper_band = old_ma_20 + band_width * old_std_dev;
    
    // Only place orders if bands are valid
    if lower_band > 0 && upper_band > lower_band {
        // Fixed position size (adjustable)
        let position_size = 100;
        
        // Place limit orders at bands
        orders.submit_limit_buy(lower_band, position_size);
        orders.submit_limit_sell(upper_band, position_size);
    }
}