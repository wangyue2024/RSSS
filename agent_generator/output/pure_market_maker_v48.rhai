let initialized = false;
let price_history = [];
let order_history = [];
let spread_micros = 2000;
let order_amount = 100;
let max_order_age = 3;
let price_delay = 5;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        spread_micros = 1500 + rng.rand_int(0, 1000);
        order_amount = 50 + rng.rand_int(0, 150);
    }
    
    price_history.push(market.price);
    if price_history.len() > price_delay + 1 {
        price_history.remove(0);
    }
    
    let current_tick = market.tick;
    let i = 0;
    while i < my_orders.pending_count() {
        let order_tick = my_orders.pending_placed_tick(i);
        if current_tick - order_tick > max_order_age {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if price_history.len() <= price_delay {
        return;
    }
    
    let delayed_price = price_history[0];
    let buy_price = delayed_price - spread_micros;
    let sell_price = delayed_price + spread_micros;
    
    if buy_price > 0 {
        orders.submit_limit_buy(buy_price, order_amount);
    }
    
    orders.submit_limit_sell(sell_price, order_amount);
}