let initialized = false;
let lot_size_pct = 0;
let stop_threshold = 0;
let last_price = 0;
let panic_triggered = false;
let price_history = [];
let fomo_counter = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size_pct = rng.rand_int(30, 50);
        stop_threshold = -rng.rand_int(10000, 50000);
        last_price = market.price;
        price_history.push(market.price);
        fomo_counter = 0;
        return;
    }
    
    if !market.trading_enabled { return; }
    
    if panic_triggered {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    if account.unrealized_pnl < stop_threshold && account.unrealized_pnl < 0 {
        panic_triggered = true;
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    price_history.push(market.price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    if price_history.len() >= 3 {
        let old_idx = price_history.len() - 3;
        let old_price = price_history[old_idx];
        let price_change = (market.price - old_price) * 10000 / old_price;
        if price_change > 200 {
            fomo_counter = 5;
        }
    }
    
    if fomo_counter > 0 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        if account.cash > 1000000 {
            let buy_amount = account.cash * 30 / 100 / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
        fomo_counter -= 1;
        last_price = market.price;
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let price_change = market.price - last_price;
    
    if price_change < 0 {
        let buy_price = market.price * 998 / 1000;
        if buy_price < market.bid_price_0 && buy_price > 0 {
            let buy_amount = account.cash * lot_size_pct / 100 / buy_price;
            if buy_amount > 0 {
                orders.submit_limit_buy(buy_price, buy_amount);
            }
        }
    } else if price_change > 0 && account.stock > 0 {
        let sell_price = market.price * 1002 / 1000;
        if sell_price > market.ask_price_0 && sell_price > 0 {
            let sell_amount = account.stock * lot_size_pct / 100;
            if sell_amount > 0 {
                orders.submit_limit_sell(sell_price, sell_amount);
            }
        }
    }
    
    last_price = market.price;
}