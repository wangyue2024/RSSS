let initialized = false;
let risk_percent = 0;
let buy_order_id = 0;
let sell_order_id = 0;
let last_buy_price = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        risk_percent = rng.rand_int(40, 50);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.ma_20 == 0 || market.std_dev == 0 { return; }
    
    let lower_band_raw = market.ma_20 - 2 * market.std_dev;
    let upper_band_raw = market.ma_20 + 2 * market.std_dev;
    
    let round_factor = 1_000_000;
    let lower_band = ((lower_band_raw + 500_000) / round_factor) * round_factor;
    let upper_band = ((upper_band_raw + 500_000) / round_factor) * round_factor;
    
    if lower_band > 0 {
        let cash_to_use = (account.cash * risk_percent) / 100;
        let buy_amount = cash_to_use / lower_band;
        if buy_amount > 0 {
            orders.submit_limit_buy(lower_band, buy_amount);
        }
    }
    
    if account.stock > 0 && upper_band > account.avg_cost {
        let sell_amount = (account.stock * risk_percent) / 100;
        if sell_amount > 0 {
            orders.submit_limit_sell(upper_band, sell_amount);
        }
    }
}