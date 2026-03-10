let initialized = false;
let price_history = [];
let imbalance_history = [];
let delayed_price = 0;
let delayed_imbalance = 0;
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        price_history = [];
        imbalance_history = [];
        fomo_triggered = false;
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    let current_imbalance = market.order_imbalance;
    
    price_history.push(current_price);
    imbalance_history.push(current_imbalance);
    
    if price_history.len() > 10 {
        price_history.remove(0);
        imbalance_history.remove(0);
    }
    
    if fomo_triggered {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_history.len() >= 4 {
        let old_price = price_history[price_history.len() - 4];
        if old_price > 0 {
            let price_change_percent = (current_price - old_price) * 10000 / old_price;
            if price_change_percent > 200 {
                let buy_amount = account.cash / current_price;
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                    fomo_triggered = true;
                    return;
                }
            }
        }
    }
    
    if price_history.len() >= 5 && imbalance_history.len() >= 5 {
        delayed_price = price_history[price_history.len() - 5];
        delayed_imbalance = imbalance_history[imbalance_history.len() - 5];
        
        let half_spread = 5000;
        let mid_price = delayed_price;
        
        let imbalance_adj = if delayed_imbalance > 5000 {
            delayed_imbalance * 100 / 1000000
        } else if delayed_imbalance < -5000 {
            delayed_imbalance * 100 / 1000000
        } else {
            0
        };
        
        let adjusted_mid = mid_price + imbalance_adj;
        let bid_price = adjusted_mid - half_spread;
        let ask_price = adjusted_mid + half_spread;
        
        if bid_price > 0 && ask_price > 0 {
            let order_qty = 100;
            
            if account.cash >= bid_price * order_qty {
                orders.submit_limit_buy(bid_price, order_qty);
            }
            
            if account.stock >= order_qty {
                orders.submit_limit_sell(ask_price, order_qty);
            }
        }
    }
}