let initialized = false;
let fair_value = 0;
let threshold_95 = 0;
let threshold_90 = 0;

fn on_tick() {
    if !initialized {
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        threshold_95 = fair_value * 95 / 100;
        threshold_90 = fair_value * 90 / 100;
        initialized = true;
    }

    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    let total_ticks = market.total_ticks;
    
    if current_tick >= total_ticks * 1 / 5 {
        let cancel_count = my_orders.pending_count();
        let i = 0;
        while i < cancel_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    let cash = account.cash;
    let avg_cost = account.avg_cost;
    let stock_held = account.stock;
    
    if current_price < fair_value {
        let spend_amount;
        if current_price < threshold_90 {
            spend_amount = cash * 50 / 100;
        } else if current_price < threshold_95 {
            spend_amount = cash * 25 / 100;
        } else {
            spend_amount = cash * 10 / 100;
        }
        
        if spend_amount > 1_000_000 {
            let buy_amt = spend_amount / current_price;
            if buy_amt > 0 {
                orders.submit_limit_buy(current_price, buy_amt);
            }
        }
    }
    
    if stock_held > 0 && current_price > avg_cost && current_price >= fair_value {
        orders.submit_limit_sell(current_price, stock_held);
    }
}