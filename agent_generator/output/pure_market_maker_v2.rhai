let initialized = false;
let spread_bps = 0;
let order_size = 0;
let price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_bps = 50;
        order_size = 100;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_history.push(market.price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    if price_history.len() == 10 {
        let old_price = price_history[0];
        let current_price = price_history[9];
        
        let change_micros = if current_price > old_price {
            (current_price - old_price) * 10000 / old_price
        } else {
            (old_price - current_price) * 10000 / old_price
        };
        
        if change_micros > 200 {
            orders.submit_market_buy(order_size);
            return;
        }
    }
    
    let buy_price = (market.price * (10000 - spread_bps)) / 10000;
    let sell_price = (market.price * (10000 + spread_bps)) / 10000;
    
    orders.submit_limit_buy(buy_price, order_size);
    orders.submit_limit_sell(sell_price, order_size);
}