let initialized = false;
let risk_percent = 0;
let price_history = [];
let current_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_percent = rng.rand_int(25, 50);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() < 5 { return; }
    
    let delayed_price = price_history[0];
    let spread = delayed_price * 50 / 10000;
    
    let raw_buy_price = delayed_price - spread;
    let raw_sell_price = delayed_price + spread;
    
    let rounded_buy_price = ((raw_buy_price + 500_000) / 1_000_000) * 1_000_000;
    let rounded_sell_price = ((raw_sell_price + 500_000) / 1_000_000) * 1_000_000;
    
    let cash_to_risk = account.cash * risk_percent / 100;
    let lot_size = cash_to_risk / delayed_price;
    
    if lot_size > 0 && rounded_buy_price > 0 {
        orders.submit_limit_buy(rounded_buy_price, lot_size);
    }
    
    if lot_size > 0 && rounded_sell_price > 0 {
        orders.submit_limit_sell(rounded_sell_price, lot_size);
    }
}