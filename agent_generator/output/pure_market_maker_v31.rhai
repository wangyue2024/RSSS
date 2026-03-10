let initialized = false;
let spread_micros = 0;
let panic_threshold_micros = 0;
let order_size = 100;

fn on_tick() {
    if !initialized {
        spread_micros = (market.price * rng.rand_int(50, 150)) / 10000;
        panic_threshold_micros = rng.rand_int(10_000, 50_000);
        order_size = rng.rand_int(80, 120);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < -panic_threshold_micros && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let half_spread = spread_micros / 2;
    let bid_price = market.price - half_spread;
    let ask_price = market.price + half_spread;
    
    if bid_price > 0 && account.cash >= bid_price * order_size {
        orders.submit_limit_buy(bid_price, order_size);
    }
    
    if ask_price > 0 && account.stock >= order_size {
        orders.submit_limit_sell(ask_price, order_size);
    }
}