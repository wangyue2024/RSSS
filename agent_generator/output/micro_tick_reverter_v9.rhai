let initialized = false;
let risk_factor = 0;
let prev_price = 0;
let prev_tick = 0;
let price_offset = 10000;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        risk_factor = rng.rand_int(25, 50);
        prev_price = market.price;
        prev_tick = market.tick;
        initialized = true;
        return;
    }
    
    if market.tick <= prev_tick { return; }
    
    let current_price = market.price;
    let price_change = current_price - prev_price;
    prev_price = current_price;
    prev_tick = market.tick;
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if my_orders.pending_count() > 0 { return; }
    
    if price_change < 0 {
        let cash_to_use = account.cash * risk_factor / 100;
        let buy_price = current_price - price_offset;
        if buy_price <= 0 { return; }
        
        let buy_amount = cash_to_use / buy_price;
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    } else if price_change > 0 && current_price > account.avg_cost && account.stock > 0 {
        let sell_amount = account.stock * risk_factor / 100;
        if sell_amount <= 0 { return; }
        
        let sell_price = current_price + price_offset;
        orders.submit_limit_sell(sell_price, sell_amount);
    }
}