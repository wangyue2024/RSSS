let initialized = false;
let pullback_threshold = 0;
let fomo_threshold = 0;
let price_history = [];
let fomo_window = 0;
let shares_per_trade = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        pullback_threshold = rng.rand_int(30, 80);
        fomo_threshold = 200;
        fomo_window = 5;
        shares_per_trade = 10;
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    let vwap = market.vwap;
    
    if vwap <= 0 { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    price_history.push(current_price);
    if price_history.len() > fomo_window {
        price_history.remove(0);
    }
    
    if price_history.len() == fomo_window {
        let old_price = price_history[0];
        if old_price > 0 {
            let price_change_percent = (current_price - old_price) * 10000 / old_price;
            if price_change_percent >= fomo_threshold {
                let buy_shares = account.cash * 50 / (100 * current_price);
                if buy_shares > 0 {
                    orders.submit_market_buy(buy_shares);
                }
                return;
            }
        }
    }
    
    if vwap > 0 && current_price > 0 {
        let discount_percent = (vwap - current_price) * 10000 / vwap;
        
        if account.stock == 0 && discount_percent >= pullback_threshold {
            let buy_price = current_price * 10025 / 10000;
            orders.submit_limit_buy(buy_price, shares_per_trade);
        } else if account.stock > 0 && current_price >= vwap {
            orders.submit_limit_sell(current_price, account.stock);
        }
    }
}