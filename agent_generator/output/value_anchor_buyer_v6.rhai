let initialized = false;
let fair_value = 0;
let threshold_90 = 0;
let threshold_95 = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        threshold_95 = fair_value * 95 / 100;
        threshold_90 = fair_value * 90 / 100;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.price >= fair_value { return; }
    
    let buy_amount = 0;
    let target_price = 0;
    
    if market.price < threshold_90 {
        buy_amount = 500;
        target_price = fair_value * 85 / 100;
    } else if market.price < threshold_95 {
        buy_amount = 200;
        target_price = fair_value * 92 / 100;
    } else {
        buy_amount = 50;
        target_price = fair_value * 97 / 100;
    }
    
    if buy_amount <= 0 { return; }
    
    let max_affordable = account.cash / target_price;
    if max_affordable <= 0 { return; }
    
    let amount_to_buy = buy_amount;
    if max_affordable < amount_to_buy {
        amount_to_buy = max_affordable;
    }
    
    if amount_to_buy <= 0 { return; }
    
    let bid_price = target_price + 1;
    orders.submit_limit_buy(bid_price, amount_to_buy);
}