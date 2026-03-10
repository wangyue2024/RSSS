// Global state
let initialized = false;
let base_lot = 100;
let current_lot = base_lot;
let last_trade_was_loss = false;
let last_processed_fill_tick = -1;
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(50, 200);
        current_lot = base_lot;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders every tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Check for FOMO condition: price jump >2% in last 5 ticks
    let short_window = 5;
    if market.history_len() >= short_window {
        let current_price = market.price;
        let past_price = market.history_price(short_window - 1);
        let price_change = (current_price - past_price) * 10000 / past_price;
        if price_change > 200 {  // >2%
            let buy_qty = rng.rand_int(current_lot, current_lot * 3);
            orders.submit_market_buy(buy_qty);
            fomo_triggered = true;
            return;
        }
    }
    
    fomo_triggered = false;
    
    // Process fills to update last trade loss status
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 && last_processed_fill_tick < market.tick {
        // Find most recent fill
        let latest_fill_idx = 0;
        let i = 1;
        while i < fill_cnt {
            if my_orders.fill_id(i) > my_orders.fill_id(latest_fill_idx) {
                latest_fill_idx = i;
            }
            i += 1;
        }
        
        let fill_price = my_orders.fill_price(latest_fill_idx);
        let fill_side = my_orders.fill_side(latest_fill_idx);
        
        // Determine if last trade was loss (buy: current price < fill price, sell: current price > fill price)
        if fill_side == 0 { // buy
            last_trade_was_loss = market.price < fill_price;
        } else { // sell
            last_trade_was_loss = market.price > fill_price;
        }
        
        last_processed_fill_tick = market.tick;
        
        // Martingale: double lot size if loss, reset if win
        if last_trade_was_loss {
            current_lot = current_lot * 2;
        } else {
            current_lot = base_lot;
        }
    }
    
    // Core random strategy
    let rand_val = rng.rand_int(0, 99);
    
    if rand_val < 5 { // Buy random
        let qty = rng.rand_int(current_lot / 2, current_lot * 2);
        let offset = rng.rand_int(-10, 10); // in micros
        let price = market.price + offset;
        if price > 0 && qty > 0 {
            orders.submit_limit_buy(price, qty);
        }
    } else if rand_val > 95 { // Sell random
        let qty = rng.rand_int(current_lot / 2, current_lot * 2);
        let offset = rng.rand_int(-10, 10);
        let price = market.price + offset;
        if price > 0 && qty > 0 && account.stock > 0 {
            orders.submit_limit_sell(price, qty);
        }
    }
}