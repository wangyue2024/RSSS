let initialized = false;
let panic_threshold = 0;
let last_prices = [];
let prev_slope = 0;
let slope_window = 20;
let fomo_window = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(5000, 20000);
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    last_prices.push(current_price);
    if last_prices.len() > slope_window {
        last_prices.remove(0);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock > 0 {
        if account.unrealized_pnl < panic_threshold {
            orders.submit_market_sell(account.stock);
            return;
        }
    }
    
    if last_prices.len() >= fomo_window {
        let old_price = last_prices[last_prices.len() - fomo_window];
        if old_price > 0 {
            let change = (current_price - old_price) * 10000 / old_price;
            if change > 200 {
                let max_buy = account.cash / current_price;
                if max_buy > 0 {
                    orders.submit_market_buy(max_buy);
                    return;
                }
            }
        }
    }
    
    if last_prices.len() >= slope_window {
        let current_slope = arr_slope(last_prices);
        
        if account.stock > 0 {
            if current_price > account.avg_cost {
                if current_slope < 0 && current_slope < prev_slope {
                    orders.submit_market_sell(account.stock);
                }
            }
        } else {
            if current_slope > 0 && current_slope > prev_slope * 2 {
                let buy_amount = (account.cash * 2500) / (10000 * current_price);
                if buy_amount > 0 {
                    orders.submit_limit_buy(current_price, buy_amount);
                }
            }
        }
        
        prev_slope = current_slope;
    }
}