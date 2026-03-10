let initialized = false;
let last_prices = [];
let slope_window = 10;
let lot_size_mult = 0;
let aggro_level = 0;

fn round_price(price) {
    ((price + 500_000) / 1_000_000) * 1_000_000
}

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size_mult = rng.rand_int(30, 50);
        aggro_level = rng.rand_int(80, 100);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    last_prices.push(market.price);
    if last_prices.len() > slope_window + 5 {
        last_prices.remove(0);
    }
    
    if last_prices.len() < slope_window + 5 {
        return;
    }
    
    let delayed_prices = [];
    let j = 0;
    while j < slope_window {
        delayed_prices.push(last_prices[j]);
        j += 1;
    }
    
    let current_slope = arr_slope(delayed_prices);
    let prev_slope = 0;
    if last_prices.len() > slope_window + 6 {
        let prev_delayed = [];
        let k = 1;
        while k <= slope_window {
            prev_delayed.push(last_prices[k]);
            k += 1;
        }
        prev_slope = arr_slope(prev_delayed);
    }
    
    let is_accelerating = current_slope > prev_slope * 120 / 100;
    let highly_positive = current_slope > 50000;
    let turned_negative = current_slope < -20000 && prev_slope > 0;
    
    let delayed_price = last_prices[4];
    let round_buy_price = round_price(delayed_price * 99 / 100);
    let round_sell_price = round_price(delayed_price * 101 / 100);
    
    if highly_positive && is_accelerating && current_slope > aggro_level * 1000 {
        let cash_to_use = account.cash * lot_size_mult / 100;
        let shares_to_buy = cash_to_use / round_buy_price;
        if shares_to_buy > 0 {
            orders.submit_limit_buy(round_buy_price, shares_to_buy);
        }
    }
    
    if turned_negative && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }
}