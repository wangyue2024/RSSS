let initialized = false;
let fair_value_micros = 0;
let action_tick = -50;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        fair_value_micros = 100_000_000 + rng.rand_int(-5_000_000, 5_000_000);
    }
    
    if market.tick < action_tick + 50 { return; }
    action_tick = market.tick;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    let avg_cost = account.avg_cost;
    
    if current_price <= avg_cost { return; }
    
    if current_price > fair_value_micros {
        let sell_amount;
        if current_price > fair_value_micros * 110 / 100 {
            sell_amount = account.stock * 30 / 100;
        } else if current_price > fair_value_micros * 105 / 100 {
            sell_amount = account.stock * 10 / 100;
        } else {
            sell_amount = 0;
        }
        
        if sell_amount > 0 {
            orders.submit_limit_sell(current_price, sell_amount);
        }
    }
}