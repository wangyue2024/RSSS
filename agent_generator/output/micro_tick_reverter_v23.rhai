let last_active_price = 0;
let last_active_tick = -100;
let lot_size = 0;
let offset = 10;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Lazy: only trade every 50 ticks
    if (market.tick % 50) != 0 { return; }
    
    // Cancel existing orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Risk-seeking: set lot size to 25-50% of cash
    let cash_to_risk = account.cash * rng.rand_int(2500, 5000) / 10000;
    if market.price > 0 {
        lot_size = cash_to_risk / market.price;
        if lot_size < 1 { lot_size = 1; }
    }
    
    // Need at least one previous tick for comparison
    if last_active_tick < 0 {
        last_active_price = market.price;
        last_active_tick = market.tick;
        return;
    }
    
    // Check price movement since last active tick
    if market.price < last_active_price {
        // Price dropped: limit buy slightly below
        let buy_price = market.price - offset;
        if buy_price > 0 {
            orders.submit_limit_buy(buy_price, lot_size);
        }
    } else if market.price > last_active_price {
        // Price rose: limit sell slightly above
        let sell_price = market.price + offset;
        if sell_price > 0 {
            orders.submit_limit_sell(sell_price, lot_size);
        }
    }
    
    // Update for next comparison
    last_active_price = market.price;
    last_active_tick = market.tick;
}