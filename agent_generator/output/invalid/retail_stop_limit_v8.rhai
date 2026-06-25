let initialized = false;
let has_entered_randomly = false;
let take_profit_price = 0;
let stop_loss_price = 0;
let fomo_triggered = false;
let price_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        price_history = [];
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    price_history.push(current_price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock == 0 {
        fomo_triggered = false;
        
        let fomo_condition = false;
        if price_history.len() >= 5 {
            let old_price = price_history[price_history.len() - 5];
            if old_price > 0 {
                if current_price * 100 > old_price * 102 {
                    fomo_condition = true;
                }
            }
        }
        
        if fomo_condition {
            let amount = 100;
            if account.cash >= current_price * amount {
                orders.submit_market_buy(amount);
                take_profit_price = (current_price * 105) / 100 + 1;
                stop_loss_price = (current_price * 98) / 100;
                fomo_triggered = true;
            }
        } else if !has_entered_randomly {
            if rng.rand_bool(1) {
                let amount = 100;
                if account.cash >= current_price * amount {
                    orders.submit_market_buy(amount);
                    take_profit_price = (current_price * 105) / 100 + 1;
                    stop_loss_price = (current_price * 98) / 100;
                    has_entered_randomly = true;
                }
            }
        }
    } else {
        if fomo_triggered || has_entered_randomly {
            if current_price > account.avg_cost {
                let tp_amount = account.stock;
                orders.submit_limit_sell(take_profit_price, tp_amount);
            }
            
            if current_price <= stop_loss_price {
                let sl_amount = account.stock;
                orders.submit_market_sell(sl_amount);
            }
        }
    }
}