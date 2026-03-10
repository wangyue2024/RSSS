let initialized = false;
let spread_micros = 0;
let max_position = 0;
let risk_factor = 0;
let max_wait_ticks = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(5000, 30000);
        risk_factor = rng.rand_int(30, 50);
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if (market.tick - placed_tick) >= max_wait_ticks {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    max_position = (account.cash * risk_factor / 100) / current_price;
    if max_position < 1 { max_position = 1; }
    
    let current_position = account.stock;
    let buy_size = max_position - current_position;
    let sell_size = max_position + current_position;
    
    if buy_size > 0 {
        let buy_price = current_price - spread_micros;
        if buy_price > 0 {
            orders.submit_limit_buy(buy_price, buy_size);
        }
    }
    
    if sell_size > 0 {
        let sell_price = current_price + spread_micros;
        orders.submit_limit_sell(sell_price, sell_size);
    }
}