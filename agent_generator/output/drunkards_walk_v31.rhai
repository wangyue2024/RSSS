let initialized = false;
let lot_size = 0;
let price_history = [];

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        lot_size = rng.rand_int(500, 5000);
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() < 5 {
        return;
    }
    
    let old_price = price_history[0];
    let roll = rng.rand_int(0, 99);
    
    if roll < 5 {
        let offset = rng.rand_int(-10000, 10000);
        let limit_price = old_price + offset;
        if limit_price < 1 { limit_price = 1; }
        
        let max_buy_cash = account.cash * 50 / 100;
        let max_shares = max_buy_cash / limit_price;
        if max_shares < 1 { max_shares = 1; }
        
        let amount = rng.rand_int(1, max_shares);
        orders.submit_limit_buy(limit_price, amount);
    } else if roll > 95 {
        let offset = rng.rand_int(-10000, 10000);
        let limit_price = old_price + offset;
        if limit_price < 1 { limit_price = 1; }
        
        let max_sell_stock = account.stock * 50 / 100;
        if max_sell_stock < 1 { max_sell_stock = 1; }
        
        let amount = rng.rand_int(1, max_sell_stock);
        orders.submit_limit_sell(limit_price, amount);
    }
}