let initialized = false;
let panic_threshold = 0;
let fomo_window = 5;
let order_amount = 100;
let last_fomo_check = 0;

fn on_tick() {
    if !initialized {
        panic_threshold = -rng.rand_int(50_000, 200_000);
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
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let history_len = market.history_len();
    if history_len >= fomo_window {
        let idx = history_len - fomo_window;
        if idx >= 0 {
            let past_price = market.history_price(idx);
            if market.price * 100 > past_price * 102 {
                orders.submit_market_buy(order_amount);
                return;
            }
        }
    }
    
    let upper_band = market.ma_20 + 2 * market.std_dev;
    let lower_band = market.ma_20 - 2 * market.std_dev;
    
    if market.bid_price_0 < lower_band && account.cash > lower_band * order_amount {
        orders.submit_limit_buy(lower_band, order_amount);
    }
    
    if market.ask_price_0 > upper_band && account.stock >= order_amount && upper_band > account.avg_cost {
        orders.submit_limit_sell(upper_band, order_amount);
    }
}