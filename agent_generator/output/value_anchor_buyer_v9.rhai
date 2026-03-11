let initialized = false;
let fair_value = 0;
let lot_size_factor = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        lot_size_factor = rng.rand_int(40, 50);
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
    if price >= fair_value { return; }
    
    let threshold_aggressive = fair_value * 90 / 100;
    let threshold_small = fair_value * 95 / 100;
    
    let fraction = if price < threshold_aggressive { lot_size_factor } else { 20 };
    let cash_to_use = account.cash * fraction / 100;
    
    if cash_to_use <= 0 { return; }
    
    let raw_order_price = price;
    let rounded_price = ((raw_order_price + 500_000) / 1_000_000) * 1_000_000;
    if rounded_price > raw_order_price {
        rounded_price = rounded_price - 1_000_000;
    }
    
    let amount = cash_to_use / rounded_price;
    if amount <= 0 { return; }
    
    orders.submit_limit_buy(rounded_price, amount);
}