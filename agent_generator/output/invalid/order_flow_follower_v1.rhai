let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { 
        return; 
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let buy_vol = market.buy_volume;
    let sell_vol = market.sell_volume;
    
    if buy_vol > 3 * sell_vol {
        let bid_price = market.bid_price_0;
        if bid_price > 0 {
            let my_price = bid_price + 1;
            orders.submit_limit_buy(my_price, 100);
        }
    } else if sell_vol > 3 * buy_vol {
        let ask_price = market.ask_price_0;
        if ask_price > 0 {
            let my_price = ask_price - 1;
            if account.stock > 0 {
                let amount = if account.stock > 100 { 100 } else { account.stock };
                orders.submit_limit_sell(my_price, amount);
            }
        }
    }
}