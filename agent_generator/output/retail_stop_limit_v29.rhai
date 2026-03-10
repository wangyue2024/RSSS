let initialized = false;
let has_entered = false;
let lot_size = 0;
let entry_price = 0;
let take_profit_id = -1;
let panic_threshold = 0;
let price_history = [];
let position_direction = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let max_capital_frac = account.total_equity * 5 / 100;
        let max_shares = max_capital_frac / market.price;
        if max_shares > 0 {
            lot_size = rng.rand_int(1, max_shares);
        } else {
            lot_size = 1;
        }
        
        panic_threshold = -rng.rand_int(10000, 30000);
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    let std_dev_threshold = market.price * 5 / 100;
    let allow_trading = market.std_dev < std_dev_threshold;
    
    if !allow_trading {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    if has_entered && account.stock == 0 {
        has_entered = false;
        entry_price = 0;
        position_direction = 0;
        take_profit_id = -1;
    }
    
    if !has_entered {
        let fomo_triggered = false;
        if price_history.len() >= 5 {
            let old_price = price_history[0];
            if old_price > 0 {
                let price_change = (market.price - old_price) * 10000 / old_price;
                if price_change > 200 {
                    fomo_triggered = true;
                }
            }
        }
        
        if fomo_triggered || rng.rand_bool(1) {
            orders.submit_market_buy(lot_size);
            has_entered = true;
            entry_price = market.price;
            position_direction = 1;
            
            let tp_price = entry_price * 105 / 100;
            take_profit_id = orders.submit_limit_sell(tp_price, lot_size);
        }
    }
    
    if has_entered && account.stock > 0 {
        if account.unrealized_pnl < panic_threshold {
            orders.submit_market_sell(account.stock);
            if take_profit_id != -1 {
                orders.submit_cancel(take_profit_id);
                take_profit_id = -1;
            }
            return;
        }
        
        let stop_price = entry_price * 98 / 100;
        if market.price <= stop_price {
            orders.submit_market_sell(account.stock);
            if take_profit_id != -1 {
                orders.submit_cancel(take_profit_id);
                take_profit_id = -1;
            }
        }
    }
}