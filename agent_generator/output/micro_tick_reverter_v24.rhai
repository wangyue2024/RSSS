let last_price = 0;
let initialized = false;

fn on_tick() {
    if !initialized {
        last_price = market.price;
        initialized = true;
        return;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    let price_change = current_price - last_price;
    
    if price_change < 0 {
        let buy_price = current_price - 100 + 1;
        let buy_amount = 100;
        orders.submit_limit_buy(buy_price, buy_amount);
    } else if price_change > 0 {
        let sell_price = current_price + 100 - 1;
        let sell_amount = 100;
        orders.submit_limit_sell(sell_price, sell_amount);
    }
    
    last_price = current_price;
}