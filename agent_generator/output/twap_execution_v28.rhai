let initialized = false;
let target_position = 50_000;
let slice_size = 500;
let ticks_between_slices = 10;
let ticks_since_last_buy = 0;
let price_history = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel any existing orders
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Update price history for FOMO detection (keep last 5 ticks)
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    // Check FOMO condition: price jumped >2% in last 5 ticks
    let current_price = market.price;
    if price_history.len() == 5 {
        let old_price = price_history[0];
        let price_change_pct = (current_price - old_price) * 10000 / old_price;
        if abs_val(price_change_pct) > 200 {  // 2% = 200/10000
            fomo_triggered = true;
        }
    }
    
    let current_stock = account.stock;
    let remaining_to_buy = target_position - current_stock;
    
    if remaining_to_buy <= 0 {
        return;
    }
    
    if fomo_triggered {
        // FOMO mode: buy all remaining immediately
        orders.submit_market_buy(remaining_to_buy);
        fomo_triggered = false;
        ticks_since_last_buy = 0;
        return;
    }
    
    // Normal TWAP execution
    ticks_since_last_buy += 1;
    
    if ticks_since_last_buy >= ticks_between_slices {
        let buy_amount = slice_size;
        if buy_amount > remaining_to_buy {
            buy_amount = remaining_to_buy;
        }
        
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
            ticks_since_last_buy = 0;
        }
    }
}