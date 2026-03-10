let initialized = false;
let lot_size = 0;
let price_history = [];
let jump_detected = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let max_trade_cash = account.total_equity * 5 / 100;
        if market.price > 0 {
            let max_shares = max_trade_cash / market.price;
            if max_shares > 0 {
                lot_size = rng.rand_int(1, max_shares);
            }
        }
    }
    
    if !market.trading_enabled { return; }
    
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
    
    if price_history.len() == 5 {
        let old_price = price_history[0];
        let current_price = price_history[4];
        if old_price > 0 {
            let change_pct = (current_price - old_price) * 10000 / old_price;
            if change_pct > 200 || change_pct < -200 {
                jump_detected = true;
            }
        }
    }
    
    if jump_detected {
        if lot_size > 0 && market.price > 0 {
            let buy_amount = clamp_val(lot_size, 1, account.cash / market.price);
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
        jump_detected = false;
        return;
    }
    
    let std_dev_threshold = market.price * 200 / 10000;
    if market.std_dev > std_dev_threshold {
        return;
    }
    
    if rng.rand_int(0, 9999) == 0 && lot_size > 0 {
        let fat_amount = lot_size * 100;
        if rng.rand_bool(50) {
            let max_buy = account.cash / market.price;
            let buy_amount = clamp_val(fat_amount, 1, max_buy);
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        } else {
            let sell_amount = clamp_val(fat_amount, 1, account.stock);
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
            }
        }
    }
}