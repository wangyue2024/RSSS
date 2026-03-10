let session_end_tick = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if session_end_tick == 0 {
        session_end_tick = market.total_ticks / 5;
    }
    
    if market.tick >= session_end_tick { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let buy_vol = market.buy_volume;
    let sell_vol = market.sell_volume;
    
    if buy_vol > sell_vol * 3 {
        let buy_amount = 100;
        let price = market.ask_price_0;
        if price > 0 {
            orders.submit_limit_buy(price, buy_amount);
        }
    }
    
    if account.stock > 0 && market.bid_price_0 > account.avg_cost {
        let sell_amount = account.stock;
        let price = market.bid_price_0;
        orders.submit_limit_sell(price, sell_amount);
    }
}