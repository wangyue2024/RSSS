let initialized = false;
let fair_value = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    let level1 = fair_value * 95 / 100;
    let level2 = fair_value * 90 / 100;
    
    let cash_for_trading = account.cash;
    let desired_buy_amount = 0;
    let bid_price = 0;
    
    if current_price < level2 {
        desired_buy_amount = 5000;
        bid_price = level2;
    } else if current_price < level1 {
        desired_buy_amount = 1000;
        bid_price = level1;
    }
    
    if desired_buy_amount > 0 && cash_for_trading > 0 {
        let max_affordable = cash_for_trading / (bid_price + 1);
        let actual_amount = if desired_buy_amount < max_affordable { desired_buy_amount } else { max_affordable };
        if actual_amount > 0 {
            orders.submit_limit_buy(bid_price + 1, actual_amount);
        }
    }
    
    if account.stock > 0 && current_price > account.avg_cost {
        let sell_amount = account.stock / 10;
        if sell_amount > 0 {
            orders.submit_limit_sell(current_price, sell_amount);
        }
    }
}