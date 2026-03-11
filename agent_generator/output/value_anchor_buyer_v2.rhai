let initialized = false;
let fair_value = 0;
let last_price = 0;
let fomo_triggered = false;
let lot_multiplier = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        lot_multiplier = rng.rand_int(250, 500);
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    
    if last_price != 0 && current_price > last_price && current_price * 10000 / last_price > 10200 {
        fomo_triggered = true;
    }
    
    if fomo_triggered {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        let buy_amount = account.cash * lot_multiplier / 1000 / current_price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        last_price = current_price;
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if current_price < fair_value {
        let limit_price;
        let cash_pct;
        
        if current_price * 100 < fair_value * 90 {
            cash_pct = 500;
            limit_price = fair_value * 90 / 100;
        } else if current_price * 100 < fair_value * 95 {
            cash_pct = 100;
            limit_price = fair_value * 95 / 100;
        } else {
            cash_pct = 0;
            limit_price = 0;
        }
        
        if cash_pct > 0 && limit_price > 0 {
            let bid_price = limit_price + 1;
            let max_shares = account.cash * cash_pct / 1000 / bid_price;
            if max_shares > 0 {
                orders.submit_limit_buy(bid_price, max_shares);
            }
        }
    }
    
    last_price = current_price;
}