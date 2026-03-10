let initialized = false;
let spread_micros = 0;
let lot_size = 0;
let risk_factor = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(500, 5000);
        risk_factor = rng.rand_int(300, 500);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let i = 0;
    while i < my_orders.pending_count() {
        let placed_at = my_orders.pending_placed_tick(i);
        if current_tick - placed_at >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let i = 0;
    let pending_ids = [];
    while i < my_orders.pending_count() {
        pending_ids.push(my_orders.pending_id(i));
        i += 1;
    }
    i = 0;
    while i < pending_ids.len() {
        orders.submit_cancel(pending_ids[i]);
        i += 1;
    }
    
    let mid_price = market.price;
    let bid_price = mid_price - spread_micros;
    let ask_price = mid_price + spread_micros;
    
    let max_buy_shares = (account.cash / 2) / market.price;
    let max_sell_shares = account.stock / 2;
    
    let buy_amount = max_buy_shares * risk_factor / 1000;
    let sell_amount = max_sell_shares * risk_factor / 1000;
    
    if bid_price > 0 && buy_amount > 0 {
        orders.submit_limit_buy(bid_price, buy_amount);
    }
    
    if ask_price > 0 && sell_amount > 0 {
        orders.submit_limit_sell(ask_price, sell_amount);
    }
}