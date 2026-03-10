let initialized = false;
let base_half_spread = 0;
let vol_factor = 0;
let risk_lot_mult = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_half_spread = rng.rand_int(5000, 25000);
        vol_factor = rng.rand_int(200, 800);
        risk_lot_mult = rng.rand_int(3000, 5000);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.tick % 50 != 0 { return; }
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let std_dev_scaled = market.std_dev * vol_factor / 10000;
    let half_spread = base_half_spread + std_dev_scaled;
    
    let bid_price = mid_price - half_spread + 1;
    let ask_price = mid_price + half_spread;
    
    if bid_price <= 0 { bid_price = 1; }
    if ask_price <= 0 { ask_price = 1; }
    
    let cash_for_trade = account.cash * risk_lot_mult / 10000;
    let buy_shares = cash_for_trade / bid_price;
    if buy_shares > 0 {
        orders.submit_limit_buy(bid_price, buy_shares);
    }
    
    let sell_shares = account.stock * risk_lot_mult / 10000;
    if sell_shares > 0 {
        orders.submit_limit_sell(ask_price, sell_shares);
    }
}