let price_buffer = [];
let panic_threshold = 0;
let initialized = false;
let order_amount = 10;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(100_000, 500_000);
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    price_buffer.push(market.price);
    
    if price_buffer.len() == 7 {
        let old_price = price_buffer[0];
        let react_price = price_buffer[1];
        let current_price = market.price;
        
        let two_percent_react = react_price * 2 / 100;
        let fomo_change = current_price - react_price;
        
        if fomo_change > two_percent_react {
            if account.cash > current_price {
                let amount = account.cash / current_price;
                orders.submit_market_buy(amount);
            }
            price_buffer.remove(0);
            return;
        }
        
        let change = react_price - old_price;
        
        if change < 0 {
            let buy_price = react_price - 1;
            orders.submit_limit_buy(buy_price, order_amount);
        } else if change > 0 {
            let sell_price = react_price + 1;
            orders.submit_limit_sell(sell_price, order_amount);
        }
        
        price_buffer.remove(0);
    }
}