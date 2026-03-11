let initialized = false;
let panic_threshold = 0;
let base_order_size = 1000;
let spread_trigger = 50000;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -1 * rng.rand_int(1000, 5000);
    }
    
    if !market.trading_enabled { return; }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let spread = market.high_20 - market.low_20;
    let dynamic_size = base_order_size;
    if spread < spread_trigger {
        dynamic_size = base_order_size * 3 / 2;
    }
    
    let buy_price = market.low_20 + spread / 20;
    let sell_price = market.high_20 - spread / 20;
    
    if market.price > buy_price && account.cash > buy_price * dynamic_size / 100 {
        orders.submit_limit_buy(buy_price, dynamic_size);
    }
    
    if market.price < sell_price && account.stock >= dynamic_size {
        orders.submit_limit_sell(sell_price, dynamic_size);
    }
}