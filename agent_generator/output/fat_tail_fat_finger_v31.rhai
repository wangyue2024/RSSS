let initialized = false;
let base_lot = 0;
let last_price = 0;
let price_history = [];
let fomo_triggered = false;
let risk_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let max_capital_use = account.total_equity * 5 / 100;
        base_lot = max_capital_use / market.price;
        if base_lot < 1 { base_lot = 1; }
        base_lot = rng.rand_int(1, base_lot);
        risk_threshold = market.price * 200 / 10000;
        last_price = market.price;
        fomo_triggered = false;
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
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    let std_dev_high = market.std_dev > risk_threshold;
    
    if price_history.len() >= 5 {
        let old_price = price_history[price_history.len() - 5];
        let price_change = (market.price - old_price) * 10000 / old_price;
        if price_change > 200 && !std_dev_high {
            fomo_triggered = true;
        }
    }
    
    if fomo_triggered {
        let buy_amount = base_lot;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        fomo_triggered = false;
        return;
    }
    
    if rng.rand_int(0, 9999) == 0 {
        let fat_amount = base_lot * 100;
        let side = rng.rand_bool(50);
        if side {
            if fat_amount > 0 {
                orders.submit_market_buy(fat_amount);
            }
        } else {
            if market.price > account.avg_cost && fat_amount > 0 {
                orders.submit_market_sell(fat_amount);
            }
        }
        return;
    }
    
    if !std_dev_high {
        if account.stock > 0 && market.price > account.avg_cost {
            let sell_amount = base_lot;
            if sell_amount > account.stock {
                sell_amount = account.stock;
            }
            if sell_amount > 0 {
                orders.submit_limit_sell(market.price, sell_amount);
            }
        }
    }
    
    last_price = market.price;
}