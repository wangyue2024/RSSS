let initialized = false;
let fair_value = 0;

fn round_to_nearest_dollar(price) {
    let remainder = price % 1_000_000;
    let rounded = price - remainder;
    if remainder >= 500_000 {
        rounded + 1_000_000
    } else {
        rounded
    }
}

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = 100_000_000 + rng.rand_int(-2_000_000, 2_000_000);
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
    let threshold_105 = fair_value * 105 / 100;
    let threshold_110 = fair_value * 110 / 100;
    
    let sell_price = round_to_nearest_dollar(current_price);
    
    if current_price > threshold_110 && account.stock >= 1000 {
        orders.submit_limit_sell(sell_price, 1000);
    } else if current_price > threshold_105 && account.stock >= 100 {
        orders.submit_limit_sell(sell_price, 100);
    }
}