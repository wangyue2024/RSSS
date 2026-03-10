let initialized = false;
let target_position = 50_000;
let slice_size = 500;
let action_interval = 50;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
    }
    
    if market.tick % action_interval != 0 { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_position = account.stock;
    
    if current_position < target_position {
        let remaining_to_target = target_position - current_position;
        let buy_amount = if slice_size < remaining_to_target { slice_size } else { remaining_to_target };
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    }
    
    if current_position > 0 && market.price > account.avg_cost {
        let sell_amount = if slice_size < current_position { slice_size } else { current_position };
        if sell_amount > 0 {
            orders.submit_market_sell(sell_amount);
        }
    }
}