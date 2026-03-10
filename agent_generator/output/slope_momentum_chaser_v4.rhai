let initialized = false;
let lookback = 10;
let slope_threshold = 1500;
let panic_threshold = -500;
let lot_multiplier = 50;
let prev_slope = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_multiplier = rng.rand_int(30, 50);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.history_len() < lookback {
        return;
    }
    
    let price_arr = [];
    let j = 0;
    while j < lookback {
        price_arr.push(market.history_price(j));
        j += 1;
    }
    let current_slope = arr_slope(price_arr);
    
    let buy_condition = current_slope > slope_threshold && current_slope > prev_slope;
    let panic_condition = current_slope < panic_threshold && market.price > account.avg_cost;
    
    if buy_condition {
        let raw_price = market.price * 105 / 100;
        let rounded_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
        let amount = account.cash * lot_multiplier / 100 / rounded_price;
        if amount > 0 {
            orders.submit_limit_buy(rounded_price, amount);
        }
    }
    
    if panic_condition && account.stock > 0 {
        let sell_amount = account.stock * lot_multiplier / 100;
        if sell_amount > 0 {
            orders.submit_market_sell(sell_amount);
        }
    }
    
    prev_slope = current_slope;
}