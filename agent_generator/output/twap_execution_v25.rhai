let initialized = false;
let risk_factor = 0;
let target_shares = 50000;
let interval = 50;
let next_action_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_factor = rng.rand_int(40, 50);
        next_action_tick = market.tick + rng.rand_int(0, interval - 1);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= next_action_tick {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        let current_position = account.stock;
        if current_position < target_shares {
            let remaining = target_shares - current_position;
            let cash_to_use = account.cash * risk_factor / 100;
            let max_shares_by_cash = cash_to_use / market.price;
            let buy_amount = arr_min([remaining, max_shares_by_cash, 500]);
            
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
        
        next_action_tick = market.tick + interval;
    }
}