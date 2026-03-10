let initialized = false;
let price_history = [];
let panic_threshold = 0;
let sell_only_if_profitable = true;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(1_000, 10_000);
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
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
        return;
    }
    
    if price_history.len() < 5 {
        return;
    }
    
    let delayed_price = price_history[0];
    let random_val = rng.rand_int(0, 99);
    
    if random_val < 5 {
        let qty = rng.rand_int(1, 100);
        let offset = rng.rand_int(-1000, 1000);
        let limit_price = delayed_price + offset;
        if limit_price <= 0 {
            limit_price = 1;
        }
        orders.submit_limit_buy(limit_price, qty);
    }
    
    if random_val > 95 && account.stock > 0 && (!sell_only_if_profitable || delayed_price > account.avg_cost) {
        let qty = rng.rand_int(1, account.stock);
        let offset = rng.rand_int(-500, 500);
        let limit_price = delayed_price + offset;
        if limit_price <= 0 {
            limit_price = 1;
        }
        orders.submit_limit_sell(limit_price, qty);
    }
}