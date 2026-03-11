let initialized = false;
let fair_value = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
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
    let avg_cost = account.avg_cost;
    
    if current_price < fair_value {
        let buy_amount = 0;
        let threshold1 = fair_value * 95 / 100;
        let threshold2 = fair_value * 90 / 100;
        
        if current_price < threshold2 {
            buy_amount = 50;
        } else if current_price < threshold1 {
            buy_amount = 10;
        }
        
        if buy_amount > 0 {
            let raw_bid = current_price;
            let half_dollar = 500_000;
            let rounded = ((raw_bid + half_dollar) / 1_000_000) * 1_000_000;
            let final_bid = rounded + 1;
            let cost = final_bid * buy_amount;
            if cost <= account.cash {
                orders.submit_limit_buy(final_bid, buy_amount);
            }
        }
    }
    
    if current_price > avg_cost && current_price >= fair_value && account.stock > 0 {
        let sell_amount = 10;
        if sell_amount <= account.stock {
            let raw_ask = current_price;
            let half_dollar = 500_000;
            let rounded_ask = ((raw_ask + half_dollar) / 1_000_000) * 1_000_000;
            orders.submit_limit_sell(rounded_ask, sell_amount);
        }
    }
}