let initialized = false;
let lot_size = 0;
let sensitivity = 20_000;
let spread = 50_000;
let std_dev_threshold = 80_000;
let start_aggressiveness = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        let five_percent_capital = account.total_equity * 5 / 100;
        let max_shares = five_percent_capital / market.price;
        lot_size = rng.rand_int(1, max_shares);
        if lot_size < 1 { lot_size = 1; }
        start_aggressiveness = rng.rand_int(30, 70);
    }
    
    if !market.trading_enabled { return; }
    if market.total_ticks <= 0 { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.tick * 100 / market.total_ticks >= 20 { return; }
    if market.std_dev > std_dev_threshold { return; }
    
    let imbalance = market.order_imbalance;
    let shift = imbalance * sensitivity / 100;
    let base_price = market.price + shift;
    
    let rounded_price = (base_price / 1_000_000) * 1_000_000;
    if base_price % 1_000_000 >= 500_000 {
        rounded_price = rounded_price + 1_000_000;
    }
    if base_price % 1_000_000 <= -500_000 {
        rounded_price = rounded_price - 1_000_000;
    }
    
    let bid_price = rounded_price - spread;
    let ask_price = rounded_price + spread;
    
    if bid_price > 0 {
        orders.submit_limit_buy(bid_price, lot_size);
    }
    if ask_price > 0 {
        orders.submit_limit_sell(ask_price, lot_size);
    }
}