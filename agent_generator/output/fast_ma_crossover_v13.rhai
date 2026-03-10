let last_tick_evaluated = -50;
let last_ma5 = 0;
let last_ma20 = 0;
let position = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    let tick = market.tick;
    
    if tick - last_tick_evaluated < 50 { return; }
    last_tick_evaluated = tick;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_ma5 = market.ma_5;
    let current_ma20 = market.ma_20;
    
    if last_ma5 != 0 && last_ma20 != 0 {
        let prev_ma5_above = last_ma5 > last_ma20;
        let curr_ma5_above = current_ma5 > current_ma20;
        
        if !prev_ma5_above && curr_ma5_above && market.ask_price_0 > 0 {
            let cash_available = account.cash;
            let buy_price = market.ask_price_0 + 1;
            let amount = cash_available / buy_price;
            if amount > 0 {
                orders.submit_limit_buy(buy_price, amount);
                position = 1;
            }
        } else if prev_ma5_above && !curr_ma5_above && account.stock > 0 && market.bid_price_0 > 0 {
            let sell_amount = account.stock;
            let sell_price = market.bid_price_0 - 1;
            orders.submit_limit_sell(sell_price, sell_amount);
            position = 0;
        }
    }
    
    last_ma5 = current_ma5;
    last_ma20 = current_ma20;
}