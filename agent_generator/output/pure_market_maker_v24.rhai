let initialized = false;
let lot_size = 0;
let spread = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        let max_lot_value = account.total_equity * 5 / 100;
        let max_shares = max_lot_value / market.price;
        if max_shares < 1 {
            max_shares = 1;
        }
        lot_size = rng.rand_int(1, max_shares);
        spread = rng.rand_int(50_000, 200_000);
        initialized = true;
    }
    
    let two_percent_threshold = market.price * 2 / 100;
    if market.std_dev > two_percent_threshold {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let bid_price = market.price - spread + 1;
    let ask_price = market.price + spread;
    
    if bid_price > 0 && account.cash >= bid_price * lot_size {
        orders.submit_limit_buy(bid_price, lot_size);
    }
    
    if ask_price > account.avg_cost && account.stock >= lot_size {
        orders.submit_limit_sell(ask_price, lot_size);
    }
}