let initialized = false;
let prev_ma_5 = 0;
let prev_ma_20 = 0;
let position = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        prev_ma_5 = market.ma_5;
        prev_ma_20 = market.ma_20;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let curr_ma_5 = market.ma_5;
    let curr_ma_20 = market.ma_20;
    
    let cross_up = prev_ma_5 <= prev_ma_20 && curr_ma_5 > curr_ma_20;
    let cross_down = prev_ma_5 >= prev_ma_20 && curr_ma_5 < curr_ma_20;
    
    if cross_up {
        let bid_price = market.bid_price_0 + 1;
        let amount = account.cash / bid_price;
        if amount > 0 && bid_price > 0 {
            orders.submit_limit_buy(bid_price, amount);
        }
    }
    
    if cross_down && account.stock > 0 {
        let ask_price = market.ask_price_0 - 1;
        if ask_price > 0 {
            orders.submit_limit_sell(ask_price, account.stock);
        } else {
            orders.submit_market_sell(account.stock);
        }
    }
    
    prev_ma_5 = curr_ma_5;
    prev_ma_20 = curr_ma_20;
}