let initialized = false;
let fair_value = 0;
let panic_threshold = 0;
let price_history = [];
let last_evaluated_tick = -100;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        panic_threshold = -rng.rand_int(100_000, 500_000);
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if market.tick - last_evaluated_tick < 50 { return; }
    last_evaluated_tick = market.tick;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_history.len() < 5 { return; }
    let delayed_price = price_history[0];
    
    if delayed_price < fair_value * 95 / 100 {
        let buy_amount = if delayed_price < fair_value * 90 / 100 {
            50
        } else {
            10
        };
        orders.submit_limit_buy(delayed_price, buy_amount);
    }
}