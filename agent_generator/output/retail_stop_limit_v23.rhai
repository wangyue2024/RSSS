let entered = false;
let entry_price = 0;
let stop_price = 0;
let tp_price = 0;
let take_profit_order_id = 0;
let entry_attempted = false;

fn round_to_dollar(micros) {
    let dollar = 1_000_000;
    let remainder = micros % dollar;
    if remainder >= 500_000 {
        ((micros / dollar) + 1) * dollar
    } else {
        (micros / dollar) * dollar
    }
}

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !entered {
        if !entry_attempted && account.stock == 0 {
            let random_decision = rng.rand_int(0, 99);
            if random_decision < 50 {
                let amount = rng.rand_int(1, 10);
                let current_price = market.price;
                let buy_price = round_to_dollar(current_price);
                orders.submit_limit_buy(buy_price, amount);
                entry_attempted = true;
            }
        }
        
        if account.stock > 0 {
            entered = true;
            entry_price = account.avg_cost;
            
            tp_price = round_to_dollar(entry_price * 105 / 100);
            stop_price = round_to_dollar(entry_price * 98 / 100);
            
            take_profit_order_id = orders.submit_limit_sell(tp_price, account.stock);
        }
    } else {
        if account.stock > 0 {
            if market.price <= stop_price {
                if take_profit_order_id != 0 {
                    orders.submit_cancel(take_profit_order_id);
                }
                orders.submit_market_sell(account.stock);
                entered = false;
                entry_price = 0;
                stop_price = 0;
                tp_price = 0;
                take_profit_order_id = 0;
            } else {
                let tp_still_pending = false;
                let pending_count = my_orders.pending_count();
                let i = 0;
                while i < pending_count {
                    if my_orders.pending_id(i) == take_profit_order_id {
                        tp_still_pending = true;
                        break;
                    }
                    i += 1;
                }
                if !tp_still_pending {
                    entered = false;
                    entry_price = 0;
                    stop_price = 0;
                    tp_price = 0;
                    take_profit_order_id = 0;
                }
            }
        } else {
            entered = false;
            entry_price = 0;
            stop_price = 0;
            tp_price = 0;
            take_profit_order_id = 0;
        }
    }
}