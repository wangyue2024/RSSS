let price_history = [];
let initialized = false;
let base_lot_size = 0;
let fomo_triggered = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        let max_capital_5pct = account.total_equity * 5 / 100;
        let max_shares = max_capital_5pct / market.price;
        if max_shares == 0 {
            base_lot_size = 1;
        } else {
            base_lot_size = rng.rand_int(1, max_shares);
        }
        initialized = true;
    }
    
    price_history.push(market.price);
    if price_history.len() > 25 {
        price_history.remove(0);
    }
    
    let std_threshold = market.price * 5 / 100;
    if market.std_dev > std_threshold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    if price_history.len() >= 3 {
        let current_price = market.price;
        let price_3_ago = price_history[price_history.len() - 3];
        let jump_pct = (current_price - price_3_ago) * 100 / price_3_ago;
        if jump_pct > 2 {
            orders.submit_market_buy(base_lot_size);
            fomo_triggered = true;
            return;
        }
    }
    
    if fomo_triggered {
        return;
    }
    
    if price_history.len() >= 5 {
        let delayed_price = price_history[price_history.len() - 5];
        
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        let range = market.high_20 - market.low_20;
        let spread_offset = range * 5 / 100;
        
        let buy_price = market.low_20 + spread_offset;
        let sell_price = market.high_20 - spread_offset;
        
        let range_narrow = range < (delayed_price * 2 / 100);
        let lot_size = if range_narrow {
            base_lot_size * 150 / 100
        } else {
            base_lot_size
        };
        
        if buy_price > 0 && lot_size > 0 {
            orders.submit_limit_buy(buy_price, lot_size);
        }
        if sell_price > 0 && lot_size > 0 {
            orders.submit_limit_sell(sell_price, lot_size);
        }
    }
}