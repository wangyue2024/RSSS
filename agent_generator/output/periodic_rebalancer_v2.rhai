let initialized = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
    }
    
    if market.tick % 50 != 0 { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let total_equity = account.total_equity;
    if total_equity <= 0 { return; }
    
    let stock_value = account.stock * market.price;
    let stock_pct = stock_value * 100_00 / total_equity;
    
    let target_pct = 50_00;
    let upper_threshold = 55_00;
    let lower_threshold = 45_00;
    
    if stock_pct > upper_threshold {
        let over_value = stock_value - (total_equity * target_pct / 100_00);
        let sell_amount = over_value / market.price;
        if sell_amount > 0 {
            let limit_price = market.bid_price_0 - 1;
            if limit_price > 0 {
                orders.submit_limit_sell(limit_price, sell_amount);
            }
        }
    } else if stock_pct < lower_threshold {
        let under_value = (total_equity * target_pct / 100_00) - stock_value;
        let buy_amount = under_value / market.price;
        if buy_amount > 0 {
            let limit_price = market.ask_price_0 + 1;
            orders.submit_limit_buy(limit_price, buy_amount);
        }
    }
}