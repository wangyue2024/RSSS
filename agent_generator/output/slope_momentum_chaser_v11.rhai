let price_buffer = [];
let prev_slope = 0;
let prev_slope2 = 0;
let window_size = 20;
let delay = 5;
let buy_threshold = 1500;
let panic_threshold = -800;
let initialized = false;

fn round_price(price) {
    let half_dollar = 500_000;
    return (price + half_dollar) / 1_000_000 * 1_000_000;
}

fn on_tick() {
    if !initialized {
        initialized = true;
        buy_threshold = rng.rand_int(1000, 2000);
        panic_threshold = rng.rand_int(-1200, -400);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_buffer.push(market.price);
    if price_buffer.len() > window_size + delay {
        price_buffer.remove(0);
    }
    
    if price_buffer.len() == window_size + delay {
        let delayed_prices = [];
        let j = 0;
        while j < window_size {
            delayed_prices.push(price_buffer[j]);
            j += 1;
        }
        
        let slope = math.slope(delayed_prices);
        let accel = slope - prev_slope;
        let prev_accel = prev_slope - prev_slope2;
        
        if account.stock > 0 && slope < panic_threshold {
            orders.submit_market_sell(account.stock);
        } else if account.stock == 0 && slope > buy_threshold && accel > 0 && prev_accel > 0 {
            let raw_target = market.price * 998 / 1000;
            let round_target = round_price(raw_target);
            let max_afford = account.cash / round_target;
            let amount = max_afford * 60 / 100;
            if amount > 0 {
                orders.submit_limit_buy(round_target, amount);
            }
        }
        
        prev_slope2 = prev_slope;
        prev_slope = slope;
    }
}