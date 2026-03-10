let initialized = false;
let panic_threshold = 0;
let entry_price = 0;
let has_position = false;
let tp_order_id = 0;
let tp_placed = false;
let panic_sold = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(5000, 20000);
    }
    
    if !market.trading_enabled { return; }
    
    if !has_position {
        if account.stock == 0 {
            if rng.rand_bool(1) {
                let amount = account.cash / market.price;
                if amount > 0 {
                    orders.submit_market_buy(amount);
                }
            }
        } else {
            has_position = true;
            entry_price = account.avg_cost;
        }
        return;
    }
    
    if account.stock == 0 {
        has_position = false;
        tp_placed = false;
        tp_order_id = 0;
        return;
    }
    
    if !tp_placed {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        
        let tp_price = entry_price * 105 / 100;
        tp_order_id = orders.submit_limit_sell(tp_price, account.stock);
        tp_placed = true;
    }
    
    if account.unrealized_pnl < panic_threshold && !panic_sold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        orders.submit_market_sell(account.stock);
        panic_sold = true;
        return;
    }
    
    let stop_price = entry_price * 98 / 100;
    if market.price <= stop_price && !panic_sold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        orders.submit_market_sell(account.stock);
        panic_sold = true;
    }
}