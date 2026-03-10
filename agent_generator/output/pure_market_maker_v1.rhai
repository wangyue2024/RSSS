let initialized = false;
let spread_percentage = 50;
let order_amount = 100;
let fomo_threshold = 200;
let fomo_window = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_percentage = rng.rand_int(40, 60);
        order_amount = rng.rand_int(80, 120);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.history_len() > fomo_window {
        let current_price = market.price;
        let past_price = market.history_price(fomo_window);
        let price_change = abs_val(current_price - past_price) * 10000 / past_price;
        
        if price_change > fomo_threshold {
            orders.submit_market_buy(order_amount);
            return;
        }
    }
    
    let spread_micros = market.price * spread_percentage / 10000;
    let buy_price = market.price - spread_micros;
    let sell_price = market.price + spread_micros;
    
    let buy_cost = buy_price * order_amount;
    if buy_cost <= account.cash {
        orders.submit_limit_buy(buy_price, order_amount);
    }
    
    if order_amount <= account.stock {
        orders.submit_limit_sell(sell_price, order_amount);
    }
}