let initialized = false;
let has_position = false;
let entry_price = 0;
let take_profit_id = -1;
let stop_loss_triggered = false;
let morning_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        morning_ticks = market.total_ticks / 5;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= morning_ticks {
        return;
    }
    
    if !has_position && account.stock == 0 {
        if rng.rand_bool(2) {
            let cash_to_use = account.cash * 20 / 100;
            let buy_amount = cash_to_use / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
                entry_price = account.avg_cost;
                has_position = true;
                stop_loss_triggered = false;
            }
        }
        return;
    }
    
    if has_position && account.stock > 0 && entry_price > 0 {
        if my_orders.pending_count() == 0 && !stop_loss_triggered {
            let raw_tp_price = entry_price * 105 / 100;
            let rounded_tp_price = ((raw_tp_price + 500_000) / 1_000_000) * 1_000_000;
            
            if rounded_tp_price > market.price {
                take_profit_id = orders.submit_limit_sell(rounded_tp_price, account.stock);
            }
        }
        
        let stop_loss_price = entry_price * 98 / 100;
        if market.price <= stop_loss_price && !stop_loss_triggered {
            orders.submit_market_sell(account.stock);
            stop_loss_triggered = true;
            
            if take_profit_id != -1 {
                let pending = my_orders.pending_count();
                let i = 0;
                while i < pending {
                    if my_orders.pending_id(i) == take_profit_id {
                        orders.submit_cancel(take_profit_id);
                        break;
                    }
                    i += 1;
                }
            }
        }
        
        if account.stock == 0 {
            has_position = false;
            entry_price = 0;
            take_profit_id = -1;
        }
    }
}