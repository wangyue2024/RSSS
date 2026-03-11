let initialized = false;
let rebalance_counter = 0;
let stored_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        rebalance_counter = 0;
        stored_price = market.price;
    }
    
    if !market.trading_enabled { return; }
    
    // Store price from 5 ticks ago (delayed reaction)
    if market.history_len() >= 5 {
        stored_price = market.history_price(5);
    }
    
    // Cancel orders older than 3 ticks
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Rebalance every 10 ticks
    rebalance_counter += 1;
    if rebalance_counter < 10 { return; }
    rebalance_counter = 0;
    
    if stored_price == 0 { return; }
    
    // Calculate current allocation using delayed price
    let stock_value = account.stock * stored_price;
    let total_equity = account.cash + stock_value;
    if total_equity == 0 { return; }
    
    let stock_percentage = (stock_value * 10000) / total_equity;
    
    // Calculate target quantities
    let target_stock_value = (total_equity * 5000) / 10000;
    let target_shares = target_stock_value / stored_price;
    
    // Round to nearest dollar (1,000,000 micros)
    let round_price = ((market.price + 500000) / 1000000) * 1000000;
    
    if stock_percentage > 5500 {  // >55%
        // Sell excess shares
        let sell_amount = account.stock - target_shares;
        if sell_amount > 0 {
            orders.submit_limit_sell(round_price, sell_amount);
        }
    } else if stock_percentage < 4500 {  // <45%
        // Buy deficit shares
        let buy_amount = target_shares - account.stock;
        if buy_amount > 0 {
            // Check cash constraint
            let max_affordable = account.cash / round_price;
            let final_amount = if buy_amount < max_affordable { buy_amount } else { max_affordable };
            if final_amount > 0 {
                orders.submit_limit_buy(round_price, final_amount);
            }
        }
    }
}