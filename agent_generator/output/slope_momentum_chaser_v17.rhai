let initialized = false;
let window = 20;
let lot_size = 0;
let slope_threshold = 0;
let panic_slope_threshold = 0;
let prev_slope = 0;
let prev_price = 0;
let trade_cooldown = 0;

fn on_tick() {
    if !initialized {
        let max_lot_value = account.total_equity * 5 / 100;
        let max_shares = max_lot_value / market.price;
        if max_shares < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
        slope_threshold = rng.rand_int(5000, 15000);
        panic_slope_threshold = rng.rand_int(-20000, -5000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if trade_cooldown > 0 {
        trade_cooldown -= 1;
    }
    
    let current_std_dev_threshold = market.price * 2 / 100;
    if market.std_dev > current_std_dev_threshold {
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }
    
    let hist_len = market.history_len();
    if hist_len < window {
        return;
    }
    
    let prices = [];
    let idx = hist_len - window;
    while idx < hist_len {
        prices.push(market.history_price(idx));
        idx += 1;
    }
    
    let current_slope = arr_slope(prices);
    let slope_accel = current_slope - prev_slope;
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if trade_cooldown == 0 {
        if current_slope > slope_threshold && slope_accel > 0 && account.cash > market.price {
            let buy_price = market.price + 1000;
            orders.submit_limit_buy(buy_price, lot_size);
            trade_cooldown = 5;
        } else if current_slope < panic_slope_threshold && account.stock > 0 {
            orders.submit_market_sell(account.stock);
            trade_cooldown = 10;
        }
    }
    
    prev_slope = current_slope;
    prev_price = market.price;
}