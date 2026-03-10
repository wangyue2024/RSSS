let initialized = false;
let lot_size = 0;
let last_decision_tick = -100;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        let max_shares = (account.total_equity * 5) / (100 * market.price);
        if max_shares < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_tick = market.tick;
    let check_period = 50;
    
    if (current_tick % check_period != 0) {
        return;
    }
    
    if !(current_tick < market.total_ticks / 5) {
        return;
    }
    
    let five_percent_price = (market.price * 5) / 100;
    if market.std_dev > five_percent_price {
        return;
    }
    
    let buy_vol = market.buy_volume;
    let sell_vol = market.sell_volume;
    
    if buy_vol > 3 * sell_vol {
        orders.submit_market_buy(lot_size);
    }
}