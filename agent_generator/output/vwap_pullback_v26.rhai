let initialized = false;
let aggressive_pct = 0;
let threshold_bps = 0;
let last_action_tick = -1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        aggressive_pct = rng.rand_int(4000, 5000);
        threshold_bps = rng.rand_int(100, 250);
    }
    
    if !market.trading_enabled { return; }
    
    let tick = market.tick;
    if tick % 50 != 0 { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.vwap == 0 { return; }
    
    let price = market.price;
    let vwap = market.vwap;
    let deviation = (vwap - price) * 10000 / vwap;
    
    if deviation > threshold_bps && account.cash > 1000000 {
        let cash_to_use = account.cash * aggressive_pct / 10000;
        let buy_amount = cash_to_use / price;
        if buy_amount > 0 {
            orders.submit_limit_buy(price, buy_amount);
        }
    } else if deviation <= 0 && account.stock > 0 {
        let sell_amount = account.stock;
        orders.submit_limit_sell(price, sell_amount);
    }
    
    last_action_tick = tick;
}