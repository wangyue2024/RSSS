let initialized = false;
let decision_threshold = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        decision_threshold = 50;
    }
    
    if market.tick % decision_threshold != 0 { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let r = rng.rand_int(0, 99);
    
    if r < 5 {
        let cash_to_use = account.cash * rng.rand_int(25, 50) / 100;
        let price_offset = rng.rand_int(-500, 500);
        let target_price = market.price + (market.price * price_offset / 10000);
        let amount = cash_to_use / target_price;
        
        if amount > 0 && target_price > 0 {
            orders.submit_limit_buy(target_price, amount);
        }
    } else if r > 95 {
        let stock_to_sell = account.stock * rng.rand_int(25, 50) / 100;
        let price_offset = rng.rand_int(-500, 500);
        let target_price = market.price + (market.price * price_offset / 10000);
        
        if stock_to_sell > 0 && target_price > 0 {
            orders.submit_limit_sell(target_price, stock_to_sell);
        }
    }
}