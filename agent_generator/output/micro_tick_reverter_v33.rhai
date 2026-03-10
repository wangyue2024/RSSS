let price_history = [];
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        return;
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 6 {
        price_history.remove(0);
    }
    
    if price_history.len() < 6 {
        return;
    }
    
    let old_price = price_history[0];
    let new_price = price_history[1];
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let change = new_price - old_price;
    
    if change < 0 {
        let raw_price = new_price * 9995 / 10000;
        let remainder = raw_price % 1_000_000;
        let round_price = if remainder >= 500_000 {
            raw_price - remainder + 1_000_000
        } else {
            raw_price - remainder
        };
        if round_price > 0 {
            orders.submit_limit_buy(round_price, 100);
        }
    } else if change > 0 {
        let raw_price = new_price * 10005 / 10000;
        let remainder = raw_price % 1_000_000;
        let round_price = if remainder >= 500_000 {
            raw_price - remainder + 1_000_000
        } else {
            raw_price - remainder
        };
        if round_price > 0 {
            orders.submit_limit_sell(round_price, 100);
        }
    }
}