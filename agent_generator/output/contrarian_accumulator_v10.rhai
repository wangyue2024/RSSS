let initialized = false;
let price_history = [];
let rsi_history = [];
let buy_order_active = false;
let sell_order_active = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    rsi_history.push(market.rsi_14);
    
    if price_history.len() > 5 {
        price_history.remove(0);
        rsi_history.remove(0);
    }
    
    if price_history.len() < 5 { return; }
    
    let old_rsi = rsi_history[0];
    let old_price = price_history[0];
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    buy_order_active = false;
    sell_order_active = false;
    
    let trade_size = rng.rand_int(20, 100);
    
    if old_rsi < 3000 {
        let limit_price = market.price - market.price * 50 / 10000;
        if limit_price > 0 && trade_size > 0 {
            orders.submit_limit_buy(limit_price, trade_size);
            buy_order_active = true;
        }
    } else if old_rsi > 7000 {
        let limit_price = market.price + market.price * 50 / 10000;
        if limit_price > 0 && trade_size > 0 {
            orders.submit_limit_sell(limit_price, trade_size);
            sell_order_active = true;
        }
    }
}