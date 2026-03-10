let initialized = false;
let spread_micros = 0;
let panic_threshold = 0;
let order_size = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_micros = market.price * rng.rand_int(100, 300) / 10000;
        panic_threshold = -rng.rand_int(50000, 200000);
    }
    
    if !market.trading_enabled { return; }
    
    let morning_phase = market.tick * 5 < market.total_ticks;
    if !morning_phase {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    if account.unrealized_pnl < panic_threshold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let mid = market.price;
    let buy_price = mid - spread_micros;
    let sell_price = mid + spread_micros;
    
    if buy_price > 0 && account.cash >= buy_price * order_size {
        orders.submit_limit_buy(buy_price, order_size);
    }
    
    if account.stock >= order_size {
        orders.submit_limit_sell(sell_price, order_size);
    }
}