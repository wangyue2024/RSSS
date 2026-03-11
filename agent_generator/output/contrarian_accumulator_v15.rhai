let initialized = false;
let evaluation_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        evaluation_tick = rng.rand_int(0, 49);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick % 50 != evaluation_tick { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let rsi = market.rsi_14;
    let current_price = market.price;
    
    if rsi < 3000 {
        let buy_price = current_price * 995 / 1000;
        let buy_amount = rng.rand_int(20, 100);
        
        if account.cash >= buy_price * buy_amount {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
    
    if rsi > 7000 && account.stock > 0 {
        let sell_price = current_price * 1005 / 1000;
        let max_sell = account.stock;
        let sell_amount = clamp_val(rng.rand_int(20, 100), 0, max_sell);
        
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}