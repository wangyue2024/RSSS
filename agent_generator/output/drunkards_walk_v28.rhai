let initialized = false;
let panic_threshold = 0;
let min_amount = 0;
let max_amount = 0;
let min_offset = 0;
let max_offset = 0;

fn on_tick() {
    if !initialized {
        panic_threshold = -rng.rand_int(5000, 50000);
        min_amount = 1;
        max_amount = rng.rand_int(1, 10);
        min_offset = 1;
        max_offset = rng.rand_int(10, 100);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pcount = my_orders.pending_count();
    let i = 0;
    while i < pcount {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let rand_val = rng.rand_int(0, 99);
    
    if rand_val < 5 {
        let amount = rng.rand_int(min_amount, max_amount);
        let offset = rng.rand_int(min_offset, max_offset);
        let price = market.price - offset;
        if price < 1 { price = 1; }
        if amount > 0 {
            orders.submit_limit_buy(price, amount);
        }
    } else if rand_val > 95 {
        let amount = rng.rand_int(min_amount, max_amount);
        let offset = rng.rand_int(min_offset, max_offset);
        let price = market.price + offset;
        if amount > 0 {
            orders.submit_limit_sell(price, amount);
        }
    }
}