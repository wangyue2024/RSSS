let initialized = false;
let state = 0;
let panic_threshold = 0;
let entry_price = 0;
let take_profit_price = 0;
let stop_loss_price = 0;
let limit_order_tick = 0;
let limit_order_id = 0;

fn on_tick() {
    if !initialized {
        panic_threshold = rng.rand_int(-200000, -50000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        state = 0;
        return;
    }
    
    if state == 0 {
        if rng.rand_bool(1) && account.cash > 100000000 {
            let buy_amount = account.cash / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
                state = 1;
            }
        }
    } else if state == 1 {
        if account.stock > 0 {
            entry_price = account.avg_cost;
            take_profit_price = entry_price * 105 / 100;
            stop_loss_price = entry_price * 98 / 100;
            limit_order_tick = market.tick;
            let oid = orders.submit_limit_sell(take_profit_price, account.stock);
            if oid != 0 {
                limit_order_id = oid;
                state = 2;
            }
        }
    } else if state == 2 {
        if account.stock == 0 {
            state = 0;
            return;
        }
        
        if market.price <= stop_loss_price {
            orders.submit_market_sell(account.stock);
            state = 0;
            return;
        }
        
        let found = false;
        let cnt = my_orders.pending_count();
        let j = 0;
        while j < cnt {
            if my_orders.pending_id(j) == limit_order_id {
                found = true;
                if market.tick - limit_order_tick >= 3 {
                    orders.submit_cancel(limit_order_id);
                    limit_order_tick = market.tick;
                    limit_order_id = orders.submit_limit_sell(take_profit_price, account.stock);
                }
                break;
            }
            j += 1;
        }
        
        if !found && account.stock > 0 {
            limit_order_tick = market.tick;
            limit_order_id = orders.submit_limit_sell(take_profit_price, account.stock);
        }
    }
}