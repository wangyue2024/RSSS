let initialized = false;
let entered = false;
let entry_price = 0;
let take_profit_order = 0;
let stop_loss_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks / 5 {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    if !entered {
        if rng.rand_bool(10) {
            let amt = 100;
            entry_price = market.price;
            orders.submit_market_buy(amt);
            entered = true;
            stop_loss_triggered = false;
            
            let tp_price = entry_price * 105 / 100;
            take_profit_order = orders.submit_limit_sell(tp_price, amt);
        }
        return;
    }
    
    if account.stock > 0 {
        if !stop_loss_triggered {
            let stop_price = entry_price * 98 / 100;
            if market.price <= stop_price {
                orders.submit_market_sell(account.stock);
                orders.submit_cancel(take_profit_order);
                stop_loss_triggered = true;
            }
        }
    } else {
        entered = false;
        stop_loss_triggered = false;
    }
}