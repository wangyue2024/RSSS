let initialized = false;
let spread_micros = 0;
let order_amount = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(100_000, 300_000);
        order_amount = rng.rand_int(50, 200);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.tick * 100 / market.total_ticks < 20 {
        let mid = market.price;
        let buy_price = mid - spread_micros;
        let sell_price = mid + spread_micros;
        
        if buy_price > 0 && account.cash >= buy_price * order_amount {
            orders.submit_limit_buy(buy_price, order_amount);
        }
        
        if account.stock >= order_amount {
            orders.submit_limit_sell(sell_price, order_amount);
        }
    }
}