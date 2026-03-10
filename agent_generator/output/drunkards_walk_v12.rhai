let initialized = false;
let lot_size = 0;
let std_dev_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let capital_in_shares = account.total_equity / market.price;
        let five_percent_cap = capital_in_shares * 5 / 100;
        if five_percent_cap < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, five_percent_cap);
        }
        
        std_dev_threshold = market.price * 2 / 100;
    }
    
    if !market.trading_enabled { return; }
    
    if market.std_dev > std_dev_threshold {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let roll = rng.rand_int(0, 99);
    
    if roll < 5 {
        let qty = rng.rand_int(1, lot_size);
        let offset_percent = rng.rand_int(-50, 50);
        let offset_price = market.price * offset_percent / 10000;
        let price = market.price + offset_price;
        if price < 1 { price = 1; }
        orders.submit_limit_buy(price, qty);
    } else if roll > 95 {
        let qty = rng.rand_int(1, lot_size);
        let offset_percent = rng.rand_int(-50, 50);
        let offset_price = market.price * offset_percent / 10000;
        let price = market.price + offset_price;
        if price < 1 { price = 1; }
        orders.submit_limit_sell(price, qty);
    }
}