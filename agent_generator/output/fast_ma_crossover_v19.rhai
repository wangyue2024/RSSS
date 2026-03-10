let prev_ma5 = 0;
let prev_ma20 = 0;
let initialized = false;
let BUY_AMOUNT = 1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        prev_ma5 = market.ma_5;
        prev_ma20 = market.ma_20;
        return;
    }
    
    if !market.trading_enabled { return; }
    
    let curr_ma5 = market.ma_5;
    let curr_ma20 = market.ma_20;
    
    let prev_cross = prev_ma5 - prev_ma20;
    let curr_cross = curr_ma5 - curr_ma20;
    
    if prev_cross <= 0 && curr_cross > 0 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        if market.bid_price_0 > 0 {
            let bid_price = market.bid_price_0 + 1;
            orders.submit_limit_buy(bid_price, BUY_AMOUNT);
        }
    }
    
    if prev_cross >= 0 && curr_cross < 0 && market.price > account.avg_cost && account.stock > 0 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        orders.submit_market_sell(account.stock);
    }
    
    prev_ma5 = curr_ma5;
    prev_ma20 = curr_ma20;
}