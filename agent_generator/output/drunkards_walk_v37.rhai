let initialized = false;
let risk_percent = 0;
let morning_end_tick = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        risk_percent = rng.rand_int(30, 50);
        morning_end_tick = market.total_ticks * 200 / 1000;
    }
    
    if market.tick >= morning_end_tick { return; }
    
    let rand_val = rng.rand_int(0, 99);
    let action = 0;
    
    if rand_val < 5 {
        action = 1;
    } else if rand_val > 95 {
        action = -1;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if action == 1 {
        let price_offset = rng.rand_int(-5000, 5000);
        let buy_price = market.price + price_offset;
        if buy_price < 1 { buy_price = 1; }
        
        let cash_to_use = account.cash * risk_percent * rng.rand_int(1, 100) / 10000;
        if cash_to_use < 100000 { cash_to_use = 100000; }
        let quantity = cash_to_use / buy_price;
        if quantity < 100 { quantity = 100; }
        
        orders.submit_limit_buy(buy_price, quantity);
    } else if action == -1 && account.stock > 0 {
        let price_offset = rng.rand_int(-5000, 5000);
        let sell_price = market.price + price_offset;
        if sell_price < 1 { sell_price = 1; }
        
        let stock_to_sell = account.stock * risk_percent * rng.rand_int(1, 100) / 10000;
        if stock_to_sell < 100 { stock_to_sell = 100; }
        if stock_to_sell > account.stock { stock_to_sell = account.stock; }
        
        orders.submit_limit_sell(sell_price, stock_to_sell);
    }
}