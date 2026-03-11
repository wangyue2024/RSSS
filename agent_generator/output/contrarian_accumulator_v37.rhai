let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled {
        return;
    }
    
    let current_tick = market.tick;
    
    // Cancel orders older than 3 ticks
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Only place new order if no pending orders
    if my_orders.pending_count() == 0 {
        let rsi = market.rsi_14;
        
        if rsi < 3000 { // Oversold -> buy
            let amount = rng.rand_int(20, 100);
            // Limit buy 10 micro-units below best bid for aggression
            let limit_price = market.bid_price_0 - 10;
            if limit_price > 0 {
                orders.submit_limit_buy(limit_price, amount);
            }
        } else if rsi > 7000 { // Overbought -> sell
            let amount = rng.rand_int(20, 100);
            // Limit sell 10 micro-units above best ask for aggression
            let limit_price = market.ask_price_0 + 10;
            orders.submit_limit_sell(limit_price, amount);
        }
    }
}