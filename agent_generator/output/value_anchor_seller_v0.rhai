let initialized = false;
let fair_value_micros = 0;
let last_tick_evaluated = -50;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value_micros = 100_000_000 + rng.rand_int(-1_000_000, 1_000_000);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick - last_tick_evaluated < 50 { return; }
    last_tick_evaluated = market.tick;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    let avg_cost = account.avg_cost;
    let stock_to_sell = account.stock;
    
    if current_price <= fair_value_micros { return; }
    if current_price <= avg_cost { return; }
    
    let sell_amount = 0;
    
    if stock_to_sell <= 0 { return; }
    
    let threshold_105 = fair_value_micros * 105 / 100;
    let threshold_110 = fair_value_micros * 110 / 100;
    
    if current_price > threshold_110 {
        sell_amount = stock_to_sell * 80 / 100;
    } else if current_price > threshold_105 {
        sell_amount = stock_to_sell * 40 / 100;
    }
    
    if sell_amount <= 0 { return; }
    
    let limit_price = current_price + 1;
    
    if sell_amount > 0 {
        orders.submit_limit_sell(limit_price, sell_amount);
    }
}