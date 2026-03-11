let initialized = false;
let fair_value = 0;
let lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        let max_cap = account.total_equity * 5 / 100;
        if market.price > 0 {
            lot_size = max_cap / market.price;
            if lot_size < 1 {
                lot_size = 1;
            }
        } else {
            lot_size = 1;
        }
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.std_dev > (market.price * 5 / 100) {
        return;
    }
    
    if market.price < fair_value {
        let threshold1 = fair_value * 95 / 100;
        let threshold2 = fair_value * 90 / 100;
        let buy_amount = 0;
        
        if market.price < threshold2 {
            buy_amount = lot_size * 3;
        } else if market.price < threshold1 {
            buy_amount = lot_size;
        }
        
        if buy_amount > 0 && account.cash > market.price * buy_amount {
            orders.submit_limit_buy(market.price, buy_amount);
        }
    }
}