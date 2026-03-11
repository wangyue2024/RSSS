let initialized = false;
let fair_value = 0;
let threshold_small = 0;
let threshold_aggressive = 0;
let last_order_tick = -100;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(99_500_000, 100_500_000);
        threshold_small = fair_value * 105 / 100;
        threshold_aggressive = fair_value * 110 / 100;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if account.stock <= 0 { return; }
    
    let current_price = market.price;
    let avg_cost = account.avg_cost;
    
    if current_price > avg_cost && current_price > fair_value {
        let sell_price = current_price;
        let sell_amount = 0;
        
        if current_price > threshold_aggressive {
            sell_amount = account.stock * 50 / 100;
        } else if current_price > threshold_small {
            sell_amount = account.stock * 10 / 100;
        }
        
        if sell_amount > 0 && current_tick > last_order_tick + 1 {
            orders.submit_limit_sell(sell_price, sell_amount);
            last_order_tick = current_tick;
        }
    }
}