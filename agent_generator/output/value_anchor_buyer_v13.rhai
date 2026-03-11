let initialized = false;
let fair_value = 0;
let lot_size = 0;
let evaluation_interval = 50;

fn on_tick() {
    if !initialized {
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        let five_percent_capital = account.total_equity * 5 / 100;
        lot_size = rng.rand_int(100, five_percent_capital / 1000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if market.std_dev > 2_000_000 { return; }
    
    if market.tick % evaluation_interval != 0 { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let ninety_five_percent = fair_value * 95 / 100;
    let ninety_percent = fair_value * 90 / 100;
    
    if market.price < ninety_percent {
        let amount = lot_size * 2;
        if amount > 0 && account.cash >= market.price * amount {
            orders.submit_limit_buy(market.price, amount);
        }
    } else if market.price < ninety_five_percent {
        if lot_size > 0 && account.cash >= market.price * lot_size {
            orders.submit_limit_buy(market.price, lot_size);
        }
    }
}