let initialized = false;
let base_position = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_position = rng.rand_int(150, 250);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    let high_20 = market.high_20;
    let avg_cost = account.avg_cost;
    let stock_held = account.stock;
    
    if stock_held == 0 {
        if current_price > high_20 {
            let buy_amount = base_position;
            orders.submit_limit_buy(current_price, buy_amount);
        }
    } else {
        let stop_offset = micros(0, 200);
        let stop_price = avg_cost - stop_offset;
        
        if current_price > avg_cost {
            let sell_amount = stock_held;
            orders.submit_limit_sell(current_price, sell_amount);
        } else if current_price > stop_price && current_price > high_20 {
            let additional_buy = base_position;
            orders.submit_limit_buy(current_price, additional_buy);
        }
    }
}