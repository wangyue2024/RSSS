let initialized = false;
let position_active = false;
let entered_this_session = false;
let take_profit_order_id = 0;
let position_size = 0;
let stop_price = 0;
let entry_price = 0;

fn is_order_pending(order_id) {
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        if my_orders.pending_id(i) == order_id {
            return true;
        }
        i += 1;
    }
    return false;
}

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let active_period = market.tick < market.total_ticks / 5;
    
    if active_period && !position_active && !entered_this_session {
        if rng.rand_bool(10) {
            let cash_to_use = account.cash * rng.rand_int(30, 50) / 100;
            if cash_to_use > 0 && market.price > 0 {
                let amount = cash_to_use / market.price;
                if amount < 1 {
                    amount = 1;
                }
                
                orders.submit_market_buy(amount);
                entry_price = market.price;
                position_size = amount;
                
                let take_profit_price = entry_price * 105 / 100;
                orders.submit_limit_sell(take_profit_price, position_size);
                
                let pending_count = my_orders.pending_count();
                if pending_count > 0 {
                    take_profit_order_id = my_orders.pending_id(pending_count - 1);
                }
                
                stop_price = entry_price * 98 / 100;
                position_active = true;
                entered_this_session = true;
            }
        }
    }
    
    if position_active {
        if !is_order_pending(take_profit_order_id) {
            position_active = false;
        } else {
            if market.price <= stop_price {
                orders.submit_market_sell(position_size);
                orders.submit_cancel(take_profit_order_id);
                position_active = false;
            }
        }
    }
}