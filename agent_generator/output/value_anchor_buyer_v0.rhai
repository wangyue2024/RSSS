let initialized = false;
let fair_value = 0;
let lot_size = 0;
let volatility_threshold = 2_000_000;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        let max_capital = account.total_equity * 5 / 100;
        let price = market.price;
        if price > 0 {
            let max_shares = max_capital / price;
            if max_shares > 0 {
                lot_size = rng.rand_int(1, max_shares);
            } else {
                lot_size = 1;
            }
        } else {
            lot_size = 100;
        }
        initialized = true;
    }
    
    if market.std_dev > volatility_threshold {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    let aggressive_threshold = fair_value * 90 / 100;
    let moderate_threshold = fair_value * 95 / 100;
    
    if current_price < aggressive_threshold {
        let amount = lot_size * 3;
        if amount > 0 {
            let raw_price = current_price * 95 / 100;
            let round_price = (raw_price / 1_000_000) * 1_000_000;
            orders.submit_limit_buy(round_price, amount);
        }
    } else if current_price < moderate_threshold {
        let amount = lot_size;
        if amount > 0 {
            let raw_price = current_price * 97 / 100;
            let round_price = (raw_price / 1_000_000) * 1_000_000;
            orders.submit_limit_buy(round_price, amount);
        }
    }
}