let initialized = false;
let risk_factor = 0;
let lot_multiplier = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_factor = rng.rand_int(15000, 20000);
        lot_multiplier = rng.rand_int(3, 8);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.atr_14 == 0 { return; }
    
    let deviation = abs_val(market.price - market.ma_20);
    let threshold = (market.atr_14 * risk_factor) / 10000;
    
    if deviation > threshold && market.ma_20 != 0 {
        if market.price > market.ma_20 {
            let sell_amount = (account.stock * lot_multiplier) / 10;
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
            }
        } else {
            let max_shares = (account.cash * lot_multiplier) / (10 * market.price);
            let buy_amount = (max_shares * 5000) / 10000;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
        }
    }
}