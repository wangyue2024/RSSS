let initialized = false;
let fair_value = 0;
let last_action_tick = -50;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = 100_000_000 + rng.rand_int(-5_000_000, 5_000_000);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick - last_action_tick < 50 { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    let current_price = market.price;
    
    if current_price > account.avg_cost && account.stock > 0 {
        let sell_amount_small = account.stock * 10 / 100;
        if sell_amount_small == 0 { sell_amount_small = 1; }
        let sell_amount_aggressive = account.stock * 50 / 100;
        if sell_amount_aggressive == 0 { sell_amount_aggressive = 1; }
        
        let threshold1 = fair_value * 105 / 100;
        let threshold2 = fair_value * 110 / 100;
        
        if current_price > threshold2 {
            if sell_amount_aggressive > account.stock {
                sell_amount_aggressive = account.stock;
            }
            orders.submit_limit_sell(current_price, sell_amount_aggressive);
            last_action_tick = market.tick;
        } else if current_price > threshold1 {
            if sell_amount_small > account.stock {
                sell_amount_small = account.stock;
            }
            orders.submit_limit_sell(current_price, sell_amount_small);
            last_action_tick = market.tick;
        }
    }
}