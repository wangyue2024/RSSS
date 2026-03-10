let initialized = false;
let lot_size = 0;
let prev_price = 0;
let should_trade = true;

fn on_tick() {
    if !initialized {
        initialized = true;
        let five_percent_cap = account.total_equity * 5 / 100;
        let max_shares = five_percent_cap / market.price;
        if max_shares < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
        prev_price = market.price;
        return;
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
    
    let std_dev_threshold = market.price * 200 / 10000;
    if market.std_dev > std_dev_threshold {
        should_trade = false;
        return;
    } else {
        should_trade = true;
    }
    
    if !should_trade || lot_size <= 0 {
        prev_price = market.price;
        return;
    }
    
    let price_change = market.price - prev_price;
    
    if price_change < 0 {
        let buy_price = market.price * 999 / 1000;
        if account.cash >= buy_price * lot_size {
            orders.submit_limit_buy(buy_price, lot_size);
        }
    } else if price_change > 0 && account.stock >= lot_size {
        let sell_price = market.price * 1001 / 1000;
        orders.submit_limit_sell(sell_price, lot_size);
    }
    
    prev_price = market.price;
}