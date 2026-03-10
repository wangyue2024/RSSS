let initialized = false;
let lot_size = 0;
let morning_session_ratio = 0;
let risk_seeking = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        morning_session_ratio = market.total_ticks / 5;
        
        let rand_profile = rng.rand_int(0, 1);
        if rand_profile == 0 {
            risk_seeking = false;
            let max_capital_use = account.total_equity * 5 / 100;
            let max_shares = max_capital_use / market.price;
            lot_size = rng.rand_int(1, max_shares);
        } else {
            risk_seeking = true;
            let max_cash_use = account.cash * 50 / 100;
            let max_shares = max_cash_use / market.price;
            lot_size = rng.rand_int(1, max_shares);
        }
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= morning_session_ratio {
        return;
    }
    
    if !risk_seeking && market.std_dev > market.price * 15 / 100 {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let random_value = rng.rand_int(0, 99);
    
    if random_value < 5 {
        let offset = rng.rand_int(-5000, 5000);
        let price = market.price + offset;
        if price > 0 {
            let amount = rng.rand_int(1, lot_size);
            orders.submit_limit_buy(price, amount);
        }
    } else if random_value > 95 {
        let offset = rng.rand_int(-5000, 5000);
        let price = market.price + offset;
        if price > 0 {
            let amount = rng.rand_int(1, lot_size);
            orders.submit_limit_sell(price, amount);
        }
    }
}