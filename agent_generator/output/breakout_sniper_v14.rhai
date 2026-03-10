let initialized = false;
let base_lot_size = 0;
let next_trade_size = 0;
let last_trade_was_loss = false;
let stop_loss_offset = 5000;
let stop_loss_price = 0;
let last_avg_cost = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(500, 1500);
        next_trade_size = base_lot_size;
    }
    
    if !market.trading_enabled { return; }
    
    // Lazy trader: only evaluate every 50 ticks
    if market.tick % 50 != 0 { return; }
    
    // Cancel any existing orders
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Check stop loss if we have position
    if account.stock > 0 {
        if market.price < stop_loss_price {
            // Sell entire position at market
            orders.submit_market_sell(account.stock);
            
            // Determine if this trade was a loss
            if market.price < last_avg_cost {
                last_trade_was_loss = true;
                // Martingale: double lot size for next trade
                next_trade_size = base_lot_size * 2;
            } else {
                last_trade_was_loss = false;
                next_trade_size = base_lot_size;
            }
            
            // Reset stop loss
            stop_loss_price = 0;
            last_avg_cost = 0;
            return;
        }
    }
    
    // Only consider new entry if we have no position
    if account.stock == 0 {
        // Breakout condition: price breaks above 20-tick high
        if market.price > market.high_20 {
            // Aggressive buy at market
            let buy_amount = next_trade_size;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
                
                // Set stop loss below average cost
                if account.avg_cost > 0 {
                    last_avg_cost = account.avg_cost;
                    stop_loss_price = last_avg_cost - stop_loss_offset;
                }
            }
        }
    }
}