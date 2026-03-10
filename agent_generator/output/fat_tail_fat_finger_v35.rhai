let initialized = false;
let base_order_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_order_size = rng.rand_int(1, 100);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if rng.rand_int(0, 9999) == 0 {
        let fat_amount = base_order_size * 100;
        
        if rng.rand_bool(50) {
            orders.submit_market_buy(fat_amount);
        } else {
            orders.submit_market_sell(fat_amount);
        }
        return;
    }
    
    if rng.rand_int(0, 99) == 0 {
        if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
            if rng.rand_bool(50) {
                let bid_price = market.bid_price_0 + 1;
                if bid_price < market.ask_price_0 {
                    orders.submit_limit_buy(bid_price, base_order_size);
                }
            } else {
                orders.submit_limit_sell(market.ask_price_0, base_order_size);
            }
        }
    }
}