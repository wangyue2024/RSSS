let initialized = false;
let lookback = 20;
let buy_trigger_slope = 300_000;
let sell_trigger_slope = -100_000;
let prev_slope = 0;
let panic_mode = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        lookback = rng.rand_int(15, 30);
        buy_trigger_slope = rng.rand_int(250_000, 400_000);
        sell_trigger_slope = -rng.rand_int(50_000, 150_000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let hist_len = market.history_len();
    if hist_len < lookback { return; }
    
    let prices = [];
    let start_idx = hist_len - lookback;
    let idx = start_idx;
    while idx < hist_len {
        prices.push(market.history_price(idx));
        idx += 1;
    }
    
    let slope = arr_slope(prices);
    let acceleration = slope - prev_slope;
    prev_slope = slope;
    
    if panic_mode {
        if slope > 0 {
            panic_mode = false;
        } else {
            if account.stock > 0 {
                orders.submit_market_sell(account.stock);
            }
            return;
        }
    }
    
    if slope > buy_trigger_slope && acceleration > 0 {
        let raw_price = market.price;
        let round_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
        let max_buy_shares = account.cash / round_price;
        if max_buy_shares > 0 {
            let buy_shares = clamp_val(max_buy_shares * 70 / 100, 1, 100);
            orders.submit_limit_buy(round_price, buy_shares);
        }
    }
    
    if slope < sell_trigger_slope {
        panic_mode = true;
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
    }
}