let initialized = false;
let panic_threshold = 0;
let base_position = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(5000, 20000);
    }
    
    if !market.trading_enabled { return; }
    if market.tick >= market.total_ticks / 5 { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    let high = market.high_20;
    let low = market.low_20;
    let spread = high - low;
    
    if spread <= 0 { return; }
    
    let buy_price = low + spread * 5 / 100;
    let sell_price = high - spread * 5 / 100;
    
    let pos_factor = 1000000 / spread;
    let pos_factor_clamped = clamp_val(pos_factor, 100, 1000);
    let position = base_position * pos_factor_clamped / 100;
    
    if account.cash >= buy_price * position && market.tick < market.total_ticks / 5 {
        orders.submit_limit_buy(buy_price, position);
    }
    
    if account.stock >= position && sell_price > account.avg_cost && market.tick < market.total_ticks / 5 {
        orders.submit_limit_sell(sell_price, position);
    }
}