let entered = false;
let entry_price = 0;
let take_profit_order_id = 0;
let stop_loss_triggered = false;
let morning_ticks = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if morning_ticks == 0 {
        morning_ticks = market.total_ticks / 5;
    }
    
    if market.tick >= morning_ticks && !entered {
        return;
    }
    
    if !entered && market.tick < morning_ticks {
        if rng.rand_bool(5) && account.cash > 0 {
            let amount = account.cash / market.price;
            amount = clamp_val(amount, 1, 10000);
            orders.submit_market_buy(amount);
            entry_price = account.avg_cost;
            entered = true;
        }
        return;
    }
    
    if entered && account.stock > 0 {
        let pending_count = my_orders.pending_count();
        let has_tp = false;
        let i = 0;
        while i < pending_count {
            if my_orders.pending_id(i) == take_profit_order_id {
                has_tp = true;
            }
            i += 1;
        }
        
        if !has_tp && take_profit_order_id != 0 {
            take_profit_order_id = 0;
        }
        
        if take_profit_order_id == 0 && !stop_loss_triggered {
            let tp_price = entry_price * 105 / 100;
            take_profit_order_id = orders.submit_limit_sell(tp_price, account.stock);
        }
        
        let stop_price = entry_price * 98 / 100;
        if market.price <= stop_price && !stop_loss_triggered {
            orders.submit_market_sell(account.stock);
            stop_loss_triggered = true;
            
            if take_profit_order_id != 0 {
                orders.submit_cancel(take_profit_order_id);
                take_profit_order_id = 0;
            }
        }
    }
}