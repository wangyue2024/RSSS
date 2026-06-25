let initialized = false;
let lot_size = 0;
let price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        let five_percent_capital = account.total_equity * 5 / 100;
        let max_shares = five_percent_capital / market.price;
        if max_shares <= 0 {
            lot_size = 0;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
    }
    
    if !market.trading_enabled { return; }
    
    let price = market.price;
    price_history.push(price);
    if price_history.len() > 100 {
        price_history.remove(0);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let std_dev_threshold = price * 5 / 100;
    if market.std_dev > std_dev_threshold {
        return;
    }
    
    if lot_size <= 0 {
        return;
    }
    
    if price_history.len() >= 5 {
        let old_idx = price_history.len() - 5;
        let old_price = price_history[old_idx];
        let two_percent_jump = old_price * 2 / 100;
        if price > old_price + two_percent_jump {
            orders.submit_market_buy(lot_size);
            return;
        }
    }
    
    if market.history_len() > 0 {
        let last_price = market.history_price(0);
        if price < last_price {
            let offset = price * 1 / 1000;
            let limit_price = price - offset;
            let rounded_price = ((limit_price + 500_000) / 1_000_000) * 1_000_000;
            if rounded_price > 0 {
                orders.submit_limit_buy(rounded_price, lot_size);
            }
        } else if price > last_price && account.stock >= lot_size {
            let offset = price * 1 / 1000;
            let limit_price = price + offset;
            let rounded_price = ((limit_price + 500_000) / 1_000_000) * 1_000_000;
            orders.submit_limit_sell(rounded_price, lot_size);
        }
    }
}