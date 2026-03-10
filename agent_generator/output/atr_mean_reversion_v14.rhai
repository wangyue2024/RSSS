let morning_ticks = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if morning_ticks == 0 {
        morning_ticks = market.total_ticks / 5;
    }
    
    if market.tick >= morning_ticks { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let ma20 = market.ma_20;
    let atr = market.atr_14;
    let price = market.price;
    let deviation = abs_val(price - ma20);
    let threshold = (3 * atr) / 2;
    
    if deviation > threshold {
        let amount = 100;
        
        if price > ma20 {
            let buy_price = market.ask_price_0;
            if buy_price > 0 {
                orders.submit_limit_buy(buy_price + 1, amount);
            }
        } else {
            let sell_price = market.bid_price_0;
            if sell_price > 0 {
                orders.submit_limit_sell(sell_price, amount);
            }
        }
    }
}