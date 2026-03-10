let initialized = false;
let has_position = false;
let entry_tick = 0;
let take_profit_order_id = 0;
let last_cancel_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    if !has_position && account.stock > 0 {
        has_position = true;
        entry_tick = current_tick;
    }
    
    if has_position && account.stock == 0 {
        has_position = false;
        take_profit_order_id = 0;
        last_cancel_tick = 0;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        if oid != take_profit_order_id {
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if !has_position && account.stock == 0 {
        if rng.rand_bool(1) {
            let max_shares = account.cash / market.price;
            if max_shares > 0 {
                orders.submit_market_buy(max_shares);
            }
        }
        return;
    }
    
    if has_position && account.stock > 0 && account.avg_cost > 0 {
        let stop_price = account.avg_cost * 98 / 100;
        
        if market.price <= stop_price {
            orders.submit_market_sell(account.stock);
            has_position = false;
            take_profit_order_id = 0;
            last_cancel_tick = 0;
            return;
        }
        
        let tp_found = false;
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            if oid == take_profit_order_id {
                tp_found = true;
                let placed_tick = my_orders.pending_placed_tick(i);
                if current_tick - placed_tick > 3 {
                    orders.submit_cancel(oid);
                    take_profit_order_id = 0;
                    last_cancel_tick = current_tick;
                }
                break;
            }
            i += 1;
        }
        
        if !tp_found && take_profit_order_id != 0 && last_cancel_tick != current_tick {
            take_profit_order_id = 0;
        }
        
        if take_profit_order_id == 0 {
            let raw_tp_price = account.avg_cost * 105 / 100;
            let rounded_tp_price = ((raw_tp_price + 500_000) / 1_000_000) * 1_000_000;
            
            if rounded_tp_price > account.avg_cost {
                take_profit_order_id = orders.submit_limit_sell(rounded_tp_price, account.stock);
            }
        }
    }
}