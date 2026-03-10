let initialized = false;
let price_history = [];
let last_evaluation_tick = -50;
let delayed_price = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
    }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if market.tick >= market.total_ticks / 5 {
        return;
    }
    
    if market.tick - last_evaluation_tick < 50 {
        return;
    }
    
    if price_history.len() < 5 {
        return;
    }
    
    last_evaluation_tick = market.tick;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    delayed_price = price_history[0];
    
    let inventory = account.stock;
    let base_spread = 5000;
    let skew_factor = 10;
    
    let bid_skew = 0;
    let ask_skew = 0;
    
    if inventory > 1000 {
        bid_skew = inventory * skew_factor / 100;
        ask_skew = -inventory * skew_factor / 200;
    } else if inventory <= 0 {
        bid_skew = -abs_val(inventory) * skew_factor / 200;
        ask_skew = abs_val(inventory) * skew_factor / 100;
    }
    
    let bid_price = delayed_price - base_spread - bid_skew;
    let ask_price = delayed_price + base_spread - ask_skew;
    
    let min_price = 100;
    if bid_price < min_price { bid_price = min_price; }
    if ask_price < min_price { ask_price = min_price; }
    
    let order_size = 100;
    
    if bid_price > 0 {
        orders.submit_limit_buy(bid_price, order_size);
    }
    if ask_price > 0 {
        orders.submit_limit_sell(ask_price, order_size);
    }
}