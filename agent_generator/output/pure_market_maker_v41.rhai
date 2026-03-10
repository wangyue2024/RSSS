let initialized = false;
let spread_micros = 0;
let lot_size = 0;
let volatility_threshold = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        spread_micros = rng.rand_int(2000, 8000);
        let five_percent_cap = account.total_equity * 5 / 100;
        let max_lot_by_capital = five_percent_cap / market.price;
        lot_size = rng.rand_int(1, max_lot_by_capital);
        volatility_threshold = market.price * 3 / 100;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.std_dev > volatility_threshold { return; }
    
    if market.price > spread_micros {
        let bid_price = market.price - spread_micros;
        if account.cash >= bid_price * lot_size {
            orders.submit_limit_buy(bid_price, lot_size);
        }
    }
    
    let ask_price = market.price + spread_micros;
    if account.stock >= lot_size {
        orders.submit_limit_sell(ask_price, lot_size);
    }
}