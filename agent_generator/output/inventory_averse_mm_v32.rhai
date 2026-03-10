let initialized = false;
let lot_size = 0;
let panic_threshold = 0;
let max_std_dev = 0;
let skew_threshold = 1000;
let base_spread_micros = 1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        let five_percent_cap = account.total_equity * 5 / 100;
        lot_size = rng.rand_int(1, five_percent_cap);
        panic_threshold = -rng.rand_int(10000, 50000);
        max_std_dev = rng.rand_int(200000, 1000000);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if market.std_dev > max_std_dev { return; }
    
    if lot_size <= 0 { return; }
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let inventory = account.stock;
    
    let buy_distance = base_spread_micros;
    let sell_distance = base_spread_micros;
    
    if inventory > skew_threshold {
        buy_distance = buy_distance * 3 / 2;
        sell_distance = sell_distance * 1 / 2;
    } else if inventory <= 0 {
        buy_distance = buy_distance * 1 / 2;
        sell_distance = sell_distance * 3 / 2;
    }
    
    let bid_price = mid_price - buy_distance + 1;
    let ask_price = mid_price + sell_distance;
    
    if account.cash >= bid_price * lot_size {
        orders.submit_limit_buy(bid_price, lot_size);
    }
    
    if account.stock >= lot_size {
        orders.submit_limit_sell(ask_price, lot_size);
    }
}