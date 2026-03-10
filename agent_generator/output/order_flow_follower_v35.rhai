let initialized = false;
let lot_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let five_percent_cap = account.total_equity * 5 / 100;
        if market.price > 0 {
            let max_shares = five_percent_cap / market.price;
            if max_shares > 0 {
                lot_size = rng.rand_int(1, max_shares);
            } else {
                lot_size = 1;
            }
        } else {
            lot_size = 1;
        }
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let volatility_threshold = market.price * 100 / 10000;
    if market.std_dev > volatility_threshold {
        return;
    }
    
    if market.buy_volume > 3 * market.sell_volume {
        orders.submit_limit_buy(market.ask_price_0, lot_size);
    }
}