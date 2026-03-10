let initialized = false;
let spread_micros = 0;
let max_lot_pct = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(5000, 50000);
        max_lot_pct = rng.rand_int(30, 50);
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    let buy_price = current_price - spread_micros;
    let sell_price = current_price + spread_micros;
    
    // Risk-seeking buy order: up to 50% of cash
    if buy_price > 0 {
        let max_cash_use = account.cash * max_lot_pct / 100;
        let buy_amount = max_cash_use / buy_price;
        if buy_amount > 0 {
            orders.submit_limit_buy(buy_price, buy_amount);
        }
    }
    
    // Stubborn holder: only sell above average cost
    if sell_price > account.avg_cost && account.stock > 0 {
        let sell_amount = account.stock * max_lot_pct / 100;
        if sell_amount > 0 {
            orders.submit_limit_sell(sell_price, sell_amount);
        }
    }
}