let initialized = false;
let atr_multiplier = 150;
let order_lifetime_ticks = 3;
let fomo_threshold = 20000;
let fomo_window = 3;
let price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        atr_multiplier = rng.rand_int(140, 160);
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    price_history.push(current_price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let placed_at = my_orders.pending_placed_tick(i);
        if market.tick - placed_at >= order_lifetime_ticks {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if price_history.len() >= fomo_window {
        let recent_idx = price_history.len() - fomo_window;
        let old_price = price_history[recent_idx];
        if old_price != 0 {
            let change = ((current_price - old_price) * 10000) / old_price;
            if change.abs() > fomo_threshold {
                if change > 0 {
                    let buy_amount = (account.cash * 80) / (100 * current_price);
                    if buy_amount > 0 {
                        orders.submit_market_buy(buy_amount);
                    }
                }
                return;
            }
        }
    }
    
    let ma20 = market.ma_20;
    let atr = market.atr_14;
    
    if ma20 == 0 || atr == 0 { return; }
    
    let deviation = ((current_price - ma20) * 10000) / ma20;
    let threshold = (atr_multiplier * atr) / 100;
    
    if deviation.abs() > threshold {
        let base_amount = 100;
        if deviation > 0 {
            let sell_price = current_price - 1000;
            if sell_price > 0 && account.stock >= base_amount {
                orders.submit_limit_sell(sell_price, base_amount);
            }
        } else {
            let buy_price = current_price + 1000;
            let max_affordable = account.cash / buy_price;
            if buy_price > 0 && max_affordable >= base_amount {
                orders.submit_limit_buy(buy_price, base_amount);
            }
        }
    }
}