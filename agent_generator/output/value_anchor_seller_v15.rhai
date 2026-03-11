let initialized = false;
let fair_value = 0;
let lot_size = 0;
let price_history = [];
let delayed_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = micros(100, 0) + rng.rand_int(-micros(5, 0), micros(5, 0));
        lot_size = rng.rand_int(500, 2000);
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_history.len() < 5 {
        return;
    }
    
    delayed_price = price_history[0];
    
    let fair_105 = fair_value * 105 / 100;
    let fair_110 = fair_value * 110 / 100;
    
    if delayed_price > fair_value {
        let rounded_price = ((delayed_price + 500_000) / 1_000_000) * 1_000_000;
        let sell_amount;
        
        if delayed_price > fair_110 {
            sell_amount = account.stock * 50 / 100;
            sell_amount = clamp_val(sell_amount, 0, lot_size * 3);
        } else if delayed_price > fair_105 {
            sell_amount = account.stock * 25 / 100;
            sell_amount = clamp_val(sell_amount, 0, lot_size);
        } else {
            return;
        }
        
        if sell_amount > 0 {
            orders.submit_limit_sell(rounded_price, sell_amount);
        }
    }
}