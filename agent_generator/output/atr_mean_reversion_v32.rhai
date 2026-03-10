let initialized = false;
let lot_size_percent = 0;
let price_history = [];
let decision_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size_percent = rng.rand_int(40, 50);
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if market.tick % 50 != 0 { return; }
    decision_tick = market.tick;
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_history.len() < 5 { return; }
    let delayed_price = price_history[0];
    
    let ma = market.ma_20;
    let atr = market.atr_14;
    if atr <= 0 { return; }
    
    let threshold = (3 * atr) / 2;
    let deviation = delayed_price - ma;
    let abs_dev = abs_val(deviation);
    
    if abs_dev > threshold {
        if deviation > 0 {
            let amount = (account.stock * lot_size_percent) / 100;
            if amount > 0 {
                orders.submit_limit_sell(delayed_price, amount);
            }
        } else {
            let cash_to_use = (account.cash * lot_size_percent) / 100;
            let amount = cash_to_use / delayed_price;
            if amount > 0 {
                orders.submit_limit_buy(delayed_price, amount);
            }
        }
    }
}