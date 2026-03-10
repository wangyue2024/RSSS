let initialized = false;
let lot_size = 0;
let stop_offset = 0;
let morning_end_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        morning_end_tick = market.total_ticks / 5;
        let risk_percent = rng.rand_int(40, 60);
        let cash_for_trade = account.cash * risk_percent / 100;
        if market.price > 0 {
            lot_size = cash_for_trade / market.price;
            if lot_size < 1 { lot_size = 1; }
        } else {
            lot_size = 100;
        }
        stop_offset = rng.rand_int(50000, 200000);
    }
    
    if !market.trading_enabled { return; }
    if market.tick >= morning_end_tick { return; }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock > 0 {
        let stop_price = account.avg_cost - stop_offset;
        if market.price < stop_price && account.stock > 0 {
            orders.submit_market_sell(account.stock);
            return;
        }
    }
    
    if market.price > market.high_20 && account.stock == 0 {
        orders.submit_market_buy(lot_size);
    }
}