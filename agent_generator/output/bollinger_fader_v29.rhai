// Global state
let initialized = false;
let initial_lot_size = 1000;
let current_lot_size = 1000;
let last_trade_was_loss = false;
let max_lot_size = 10000;

fn on_tick() {
    if !initialized {
        initialized = true;
        current_lot_size = initial_lot_size;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all existing orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Check last trade result from fills
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        // Simple check: if we sold at a loss compared to avg_cost
        let last_fill_idx = fill_cnt - 1;
        if my_orders.fill_side(last_fill_idx) == 1 { // 1 = sell
            let sell_price = my_orders.fill_price(last_fill_idx);
            let avg_cost = account.avg_cost;
            
            if sell_price < avg_cost && avg_cost > 0 {
                last_trade_was_loss = true;
            } else {
                last_trade_was_loss = false;
            }
        }
    }
    
    // Martingale sizing
    if last_trade_was_loss {
        current_lot_size = current_lot_size * 2;
        if current_lot_size > max_lot_size {
            current_lot_size = max_lot_size;
        }
    } else {
        current_lot_size = initial_lot_size;
    }
    
    // Calculate Bollinger Bands
    let ma_20 = market.ma_20;
    let std = market.std_dev;
    
    if ma_20 == 0 || std == 0 { return; }
    
    let upper_band = ma_20 + 2 * std;
    let lower_band = ma_20 - 2 * std;
    
    // Place orders
    if account.stock < current_lot_size {
        orders.submit_limit_buy(lower_band, current_lot_size);
    }
    
    if account.stock >= current_lot_size {
        orders.submit_limit_sell(upper_band, current_lot_size);
    }
}