let last_price = 0;
let initialized = false;
let trade_amount = 100;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        last_price = market.price;
        return;
    }
    
    // Cancel all pending orders first
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    let price_change = current_price - last_price;
    
    // Only trade if we have price movement
    if price_change != 0 {
        if price_change < 0 {
            // Price dropped: place limit buy 1 micro below current price
            let buy_price = current_price - 1;
            orders.submit_limit_buy(buy_price, trade_amount);
        } else if price_change > 0 {
            // Price rose: check if we can sell profitably
            if market.price > account.avg_cost && account.stock >= trade_amount {
                // Diamond hands rule: only sell at profit
                let sell_price = current_price + 1;
                orders.submit_limit_sell(sell_price, trade_amount);
            }
        }
    }
    
    last_price = current_price;
}