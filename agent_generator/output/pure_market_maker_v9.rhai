let initialized = false;
let spread_pct = 0;
let lot_size = 0;
let price_history = [];
let max_pos = 0;

fn on_tick() {
    if !initialized {
        spread_pct = rng.rand_int(10, 30);
        let five_pct_capital = account.total_equity * 500 / 10000;
        lot_size = rng.rand_int(100, five_pct_capital / market.price);
        if lot_size < 100 { lot_size = 100; }
        max_pos = rng.rand_int(500, 2000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    if price_history.len() < 5 {
        return;
    }
    
    let old_price = price_history[price_history.len() - 5];
    let price_jump = (market.price - old_price) * 1000000 / old_price;
    
    if abs_val(price_jump) > 20000 {
        orders.submit_market_buy(lot_size);
        return;
    }
    
    let std_dev_threshold = market.price * 200 / 10000;
    if market.std_dev > std_dev_threshold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock < max_pos {
        let buy_price = old_price * (10000 - spread_pct) / 10000;
        if buy_price > 0 {
            orders.submit_limit_buy(buy_price, lot_size);
        }
    }
    
    if account.stock > 0 {
        let sell_price = old_price * (10000 + spread_pct) / 10000;
        if sell_price > 0 {
            let sell_amount = if lot_size > account.stock { account.stock } else { lot_size };
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}