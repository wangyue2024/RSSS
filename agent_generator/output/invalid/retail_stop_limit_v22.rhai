let entered = false;
let entry_price = 0;
let take_profit_id = 0;
let stop_triggered = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !entered && market.tick < market.total_ticks / 5 {
        if rng.rand_bool(3) {
            let max_shares = account.cash / market.price;
            if max_shares > 0 {
                let buy_amount = rng.rand_int(1, max_shares);
                orders.submit_market_buy(buy_amount);
                
                entry_price = account.avg_cost;
                
                let tp_price = entry_price * 105 / 100;
                orders.submit_limit_sell(tp_price, account.stock);
                
                let pending_count = my_orders.pending_count();
                let i = 0;
                while i < pending_count {
                    if my_orders.pending_side(i) == "sell" {
                        take_profit_id = my_orders.pending_id(i);
                        break;
                    }
                    i += 1;
                }
                
                entered = true;
            }
        }
    }
    
    if entered && !stop_triggered && account.stock > 0 {
        let stop_price = entry_price * 98 / 100;
        
        if market.price <= stop_price {
            if take_profit_id != 0 {
                orders.submit_cancel(take_profit_id);
            }
            orders.submit_market_sell(account.stock);
            stop_triggered = true;
        }
    }
    
    if take_profit_id != 0 {
        let found = false;
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            if my_orders.pending_id(i) == take_profit_id {
                found = true;
                break;
            }
            i += 1;
        }
        if !found {
            take_profit_id = 0;
        }
    }
}