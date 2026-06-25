let initialized = false;
let previous_ma_5 = 0;
let previous_ma_20 = 0;
let price_history = [];

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        previous_ma_5 = market.ma_5;
        previous_ma_20 = market.ma_20;
        initialized = true;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.tick >= market.total_ticks / 5 { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() == 5 {
        let old_price = price_history[0];
        if old_price > 0 && market.price > old_price {
            let jump = (market.price - old_price) * 10000 / old_price;
            if jump > 200 {
                let amount = account.cash / market.price;
                if amount > 0 {
                    orders.submit_market_buy(amount);
                }
                previous_ma_5 = market.ma_5;
                previous_ma_20 = market.ma_20;
                return;
            }
        }
    }
    
    let current_ma_5 = market.ma_5;
    let current_ma_20 = market.ma_20;
    
    if previous_ma_5 <= previous_ma_20 && current_ma_5 > current_ma_20 {
        let amount = account.cash / market.price;
        if amount > 0 {
            orders.submit_market_buy(amount);
        }
    } else if previous_ma_5 >= previous_ma_20 && current_ma_5 < current_ma_20 {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
    }
    
    previous_ma_5 = current_ma_5;
    previous_ma_20 = current_ma_20;
}