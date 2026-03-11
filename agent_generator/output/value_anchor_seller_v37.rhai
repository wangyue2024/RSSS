let initialized = false;
let fair_value_micros = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value_micros = 100_000_000 + rng.rand_int(-5_000_000, 5_000_000);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let price = market.price;
    let avg_cost = account.avg_cost;
    let stock = account.stock;
    
    if stock > 0 && price > avg_cost && price > fair_value_micros {
        let sell_amount;
        let threshold_5 = fair_value_micros * 105 / 100;
        let threshold_10 = fair_value_micros * 110 / 100;
        
        if price > threshold_10 {
            sell_amount = stock * 30 / 100;
        } else if price > threshold_5 {
            sell_amount = stock * 10 / 100;
        } else {
            sell_amount = 0;
        }
        
        if sell_amount > 0 {
            if sell_amount < 1 { sell_amount = 1; }
            orders.submit_limit_sell(price, sell_amount);
        }
    }
}