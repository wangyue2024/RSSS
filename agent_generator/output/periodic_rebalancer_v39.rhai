// Global variables
let initialized = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
    }
    
    let current_tick = market.tick;
    
    // Cancel orders older than 3 ticks
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Rebalance every 10 ticks
    if current_tick % 10 == 0 {
        let stock_value = account.stock * market.price;
        let equity = account.cash + stock_value;
        
        if equity == 0 { return; }
        
        let stock_percentage = stock_value * 10000 / equity;
        
        if stock_percentage > 5500 {
            // Stock > 55% - sell down to 50%
            let target_stock_value = equity / 2;
            let sell_value = stock_value - target_stock_value;
            let sell_amount = sell_value / market.price;
            
            if sell_amount > 0 {
                let sell_price = market.price - 1;  // Off-by-one pumper (sell cheaper)
                orders.submit_limit_sell(sell_price, sell_amount);
            }
        } else if stock_percentage < 4500 {
            // Stock < 45% - buy up to 50%
            let target_stock_value = equity / 2;
            let buy_value = target_stock_value - stock_value;
            let buy_amount = buy_value / market.price;
            
            if buy_amount > 0 {
                let buy_price = market.price + 1;  // Off-by-one pumper (buy higher)
                orders.submit_limit_buy(buy_price, buy_amount);
            }
        }
    }
}