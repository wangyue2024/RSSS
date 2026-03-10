let initialized = false;
let lot_size = 0;
let price_history = [];
let should_trade = true;

fn on_tick() {
    if !market.trading_enabled { 
        return; 
    }
    
    if !initialized {
        let five_percent_capital = account.total_equity * 500 / 10000;
        let max_shares = five_percent_capital / market.price;
        if max_shares < 1 {
            max_shares = 1;
        }
        lot_size = rng.rand_int(1, max_shares);
        initialized = true;
    }
    
    price_history.push(market.price);
    if price_history.len() > 20 {
        price_history.remove(0);
    }
    
    if price_history.len() < 5 {
        return;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let delayed_price = price_history[price_history.len() - 5];
    
    if market.std_dev * 10000 / market.price > 300 {
        should_trade = false;
        return;
    } else {
        should_trade = true;
    }
    
    if price_history.len() >= 10 {
        let old_idx = price_history.len() - 10;
        if old_idx >= 0 {
            let old_price = price_history[old_idx];
            let jump_pct = (market.price - old_price) * 10000 / old_price;
            if jump_pct > 200 || jump_pct < -200 {
                orders.submit_market_buy(lot_size);
                return;
            }
        }
    }
    
    if !should_trade {
        return;
    }
    
    let spread_pct = 50;
    let buy_price = delayed_price * (10000 - spread_pct) / 10000;
    let sell_price = delayed_price * (10000 + spread_pct) / 10000;
    
    if buy_price > 0 {
        orders.submit_limit_buy(buy_price, lot_size);
    }
    
    if sell_price > 0 {
        orders.submit_limit_sell(sell_price, lot_size);
    }
}