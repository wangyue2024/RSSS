let initialized = false;
let personality = 0;
let panic_threshold = 0;
let base_lot = 0;
let risk_cash_percent = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        personality = rng.rand_int(0, 2);
        
        if personality == 0 {
            panic_threshold = -rng.rand_int(10000, 50000);
        } else if personality == 1 {
            risk_cash_percent = rng.rand_int(25, 50);
        } else if personality == 2 {
            base_lot = rng.rand_int(1, 10);
        }
    }
    
    if !market.trading_enabled { return; }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if personality == 0 && account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if personality == 2 {
        let std_pct = market.std_dev * 10000 / market.price;
        if std_pct > 500 {
            return;
        }
    }
    
    let roll = rng.rand_int(0, 99);
    
    if roll < 5 {
        let offset = rng.rand_int(-10000, 10000);
        let price = market.price + offset;
        if price <= 0 { price = 1; }
        
        let quantity;
        if personality == 0 {
            quantity = rng.rand_int(1, 100);
        } else if personality == 1 {
            let cash_for_trade = account.cash * risk_cash_percent / 100;
            let max_shares = cash_for_trade / price;
            if max_shares > 0 {
                quantity = rng.rand_int(1, max_shares);
            } else {
                quantity = 1;
            }
        } else {
            quantity = base_lot;
        }
        
        if quantity > 0 && account.cash >= price * quantity {
            orders.submit_limit_buy(price, quantity);
        }
    } else if roll > 95 && account.stock > 0 {
        let offset = rng.rand_int(-10000, 10000);
        let price = market.price + offset;
        if price <= 0 { price = 1; }
        
        let quantity;
        if personality == 0 {
            quantity = rng.rand_int(1, 100);
        } else if personality == 1 {
            let cash_for_trade = account.cash * risk_cash_percent / 100;
            let max_shares = cash_for_trade / price;
            if max_shares > 0 {
                quantity = rng.rand_int(1, max_shares);
            } else {
                quantity = 1;
            }
        } else {
            quantity = base_lot;
        }
        
        if quantity > account.stock {
            quantity = account.stock;
        }
        
        if quantity > 0 {
            orders.submit_limit_sell(price, quantity);
        }
    }
}