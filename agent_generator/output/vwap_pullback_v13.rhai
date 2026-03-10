let initialized = false;
let threshold_bp = 0;
let lot_size_pct = 0;
let entry_vwap = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        threshold_bp = rng.rand_int(50, 200);
        lot_size_pct = rng.rand_int(30, 50);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock == 0 {
        let price = market.price;
        let vwap = market.vwap;
        
        if price * 10000 < vwap * (10000 - threshold_bp) {
            let cash_to_use = account.cash * lot_size_pct / 100;
            let shares = cash_to_use / price;
            if shares > 0 {
                orders.submit_market_buy(shares);
                entry_vwap = vwap;
            }
        }
    } else {
        if market.price >= entry_vwap {
            orders.submit_market_sell(account.stock);
        }
    }
}