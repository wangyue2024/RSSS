let price_history = [];
let spread_micros = 20;
let order_amount = 100;
let initialized = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(15, 25);
        order_amount = rng.rand_int(80, 120);
    }
    
    let morning_phase = market.tick * 5 < market.total_ticks;
    if !morning_phase { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() < 5 { return; }
    let delayed_price = price_history[0];
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let buy_price = delayed_price - spread_micros;
    let sell_price = delayed_price + spread_micros;
    
    if buy_price > 0 {
        orders.submit_limit_buy(buy_price, order_amount);
    }
    if sell_price > 0 {
        orders.submit_limit_sell(sell_price, order_amount);
    }
}