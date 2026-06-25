let initialized = false;
let history_length = 10;
let buy_slope_threshold = 3000;
let panic_slope_threshold = -2000;
let max_order_age = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
        history_length = 10;
        buy_slope_threshold = 3000;
        panic_slope_threshold = -2000;
        max_order_age = 3;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let pending_count = my_orders.pending_count();
    
    let i = 0;
    while i < pending_count {
        let order_age = current_tick - my_orders.pending_placed_tick(i);
        if order_age > max_order_age {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if market.history_len() >= history_length {
        let price_history = [];
        let j = 0;
        while j < history_length {
            price_history.push(market.history_price(j));
            j += 1;
        }
        
        let slope = arr_slope(price_history);
        
        if slope > buy_slope_threshold && account.cash > 1_000_000 {
            let buy_amount = account.cash * 10 / 100 / market.price;
            if buy_amount > 0 {
                let bid_price = market.bid_price_0;
                if bid_price > 0 {
                    orders.submit_limit_buy(bid_price, buy_amount);
                }
            }
        }
        
        if slope < panic_slope_threshold && account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
    }
}