let initialized = false;
let fair_value_micros = 0;
let pending_sell_id = 0;
let order_placed_tick = 0;

fn on_tick() {
    if !initialized {
        fair_value_micros = 100_000_000 + rng.rand_int(-5_000_000, 5_000_000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let cancel_old = false;
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        if market.tick - my_orders.pending_placed_tick(i) > 3 {
            orders.submit_cancel(oid);
            cancel_old = true;
        }
        i += 1;
    }
    
    if cancel_old {
        pending_sell_id = 0;
    }
    
    if market.tick % 50 != 0 {
        return;
    }
    
    let current_price = market.price;
    let stock_held = account.stock;
    
    if stock_held <= 0 {
        return;
    }
    
    let threshold_105 = fair_value_micros * 105 / 100;
    let threshold_110 = fair_value_micros * 110 / 100;
    
    if current_price <= threshold_105 {
        return;
    }
    
    let sell_amount = 0;
    
    if current_price > threshold_110 {
        sell_amount = stock_held * 25 / 100;
    } else {
        sell_amount = stock_held * 10 / 100;
    }
    
    if sell_amount <= 0 {
        return;
    }
    
    if pending_sell_id != 0 {
        let found = false;
        let pending_count_now = my_orders.pending_count();
        let j = 0;
        while j < pending_count_now {
            if my_orders.pending_id(j) == pending_sell_id {
                found = true;
                break;
            }
            j += 1;
        }
        if found {
            orders.submit_cancel(pending_sell_id);
        }
        pending_sell_id = 0;
    }
    
    orders.submit_limit_sell(current_price, sell_amount);
    
    let pending_count_new = my_orders.pending_count();
    if pending_count_new > 0 {
        pending_sell_id = my_orders.pending_id(pending_count_new - 1);
        order_placed_tick = market.tick;
    }
}