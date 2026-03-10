let initialized = false;
let panic_threshold = 0;
let last_price = 0;

fn on_tick() {
    if !initialized {
        panic_threshold = -rng.rand_int(1000, 5000);
        last_price = market.price;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
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
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }
    
    if last_price != 0 {
        if market.price < last_price {
            let buy_price = market.price - 1;
            let amount = 100;
            if account.cash >= buy_price * amount {
                orders.submit_limit_buy(buy_price, amount);
            }
        } else if market.price > last_price && account.stock >= 100 {
            let sell_price = market.price + 1;
            orders.submit_limit_sell(sell_price, 100);
        }
    }
    
    last_price = market.price;
}