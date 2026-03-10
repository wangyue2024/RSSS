let initialized = false;
let panic_threshold = 0;
let stop_offset = 0;
let in_position = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = rng.rand_int(10_000, 50_000);
        stop_offset = rng.rand_int(5, 15);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < 0 && abs_val(account.unrealized_pnl) > panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        in_position = false;
        return;
    }
    
    if account.stock == 0 {
        in_position = false;
    }
    
    if !in_position && market.price > market.high_20 {
        let round_price = ((market.price + 500_000) / 1_000_000) * 1_000_000;
        let buy_amount = (account.cash / 2) / round_price;
        if buy_amount > 0 {
            orders.submit_limit_buy(round_price, buy_amount);
            in_position = true;
        }
    }
    
    if in_position && account.stock > 0 {
        let stop_price = account.avg_cost - stop_offset;
        if market.price < stop_price {
            orders.submit_market_sell(account.stock);
            in_position = false;
        }
    }
}