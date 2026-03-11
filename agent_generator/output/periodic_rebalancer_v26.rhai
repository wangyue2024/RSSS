let last_rebalance_tick = -10;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.tick - last_rebalance_tick < 10 { return; }
    last_rebalance_tick = market.tick;
    
    let stock_value = account.stock * market.price;
    let equity = account.cash + stock_value;
    if equity == 0 { return; }
    
    let stock_pct = (stock_value * 100) / equity;
    
    if stock_pct > 55 && market.price > account.avg_cost {
        let target_stock_value = equity / 2;
        let excess_value = stock_value - target_stock_value;
        if excess_value <= 0 { return; }
        let shares_to_sell = excess_value / market.price;
        if shares_to_sell <= 0 { return; }
        
        let sell_price = market.bid_price_0;
        if sell_price > account.avg_cost {
            orders.submit_limit_sell(sell_price, shares_to_sell);
        }
    } else if stock_pct < 45 {
        let target_stock_value = equity / 2;
        let deficit_value = target_stock_value - stock_value;
        if deficit_value <= 0 { return; }
        let shares_to_buy = deficit_value / market.price;
        if shares_to_buy <= 0 { return; }
        
        let buy_price = market.ask_price_0;
        orders.submit_limit_buy(buy_price, shares_to_buy);
    }
}