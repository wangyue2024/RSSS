let initialized = false;
let my_order_ttl = 3;
let my_order_amount = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    // Cancel any orders older than 3 ticks
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > my_order_ttl {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Calculate Bollinger Bands
    let ma_20 = market.ma_20;
    let std_dev = market.std_dev;
    let two_std = 2 * std_dev;
    
    let lower_band = ma_20 - two_std;
    let upper_band = ma_20 + two_std;
    
    // Add 1 micro to bid price to jump ahead
    let bid_price = lower_band + 1;
    let ask_price = upper_band;
    
    // Check if we already have pending buy/sell orders
    let has_buy = false;
    let has_sell = false;
    
    let pending_check = my_orders.pending_count();
    let j = 0;
    while j < pending_check {
        let side = my_orders.pending_side(j);
        if side == 0 {
            has_buy = true;
        } else {
            has_sell = true;
        }
        j += 1;
    }
    
    // Place buy order if we don't have one
    if !has_buy && my_order_amount > 0 {
        orders.submit_limit_buy(bid_price, my_order_amount);
    }
    
    // Place sell order if we don't have one
    if !has_sell && my_order_amount > 0 {
        orders.submit_limit_sell(ask_price, my_order_amount);
    }
}