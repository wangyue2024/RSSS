let initialized = false;
let prev_price = 0;
let DOLLAR = 1_000_000;

fn on_tick() {
    if !initialized {
        initialized = true;
        prev_price = market.price;
        return;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders from previous tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let curr_price = market.price;
    
    // Determine direction: compare current to previous price
    if curr_price < prev_price {
        // Price dropped: place limit buy order slightly below current price
        // Calculate base price rounded to nearest integer dollar
        let half_dollar = DOLLAR / 2;
        let base_price = ((curr_price + half_dollar) / DOLLAR) * DOLLAR;
        // Apply off-by-one pump: add 1 micro
        let buy_price = base_price + 1;
        // Use a small fixed amount for simplicity
        let buy_amount = 100;
        // Only submit if we have enough cash
        if account.cash >= buy_price * buy_amount {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    } else if curr_price > prev_price {
        // Price rose: place limit sell order slightly above current price
        let half_dollar = DOLLAR / 2;
        let base_price = ((curr_price + half_dollar) / DOLLAR) * DOLLAR;
        // For sell, we also add 1 micro to be slightly above (consistent with quirk)
        let sell_price = base_price + 1;
        let sell_amount = 100;
        // Only submit if we have enough stock
        if account.stock >= sell_amount {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
    
    // Update previous price for next tick
    prev_price = curr_price;
}