let initialized = false;
let buy_threshold = 0;
let sell_threshold = 0;
let panic_threshold = 0;
let position_size = 0;
let slope_window = 0;
let prev_slope = 0;
let last_action_tick = 0;
let cooldown_ticks = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        buy_threshold = rng.rand_int(200, 800);
        sell_threshold = rng.rand_int(-50, 150);
        panic_threshold = rng.rand_int(-500, -200);
        position_size = rng.rand_int(50, 200);
        slope_window = rng.rand_int(10, 30);
        cooldown_ticks = rng.rand_int(3, 8);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    if current_tick - last_action_tick < cooldown_ticks { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let hist_len = market.history_len();
    if hist_len < slope_window { return; }
    
    let price_history = [];
    let start_idx = hist_len - slope_window;
    let idx = start_idx;
    while idx < hist_len {
        price_history.push(market.history_price(idx));
        idx += 1;
    }
    
    let current_slope = arr_slope(price_history);
    let slope_change = current_slope - prev_slope;
    prev_slope = current_slope;
    
    if account.stock > 0 && (current_slope < panic_threshold || (current_slope < 0 && slope_change < -100)) {
        orders.submit_market_sell(account.stock);
        last_action_tick = current_tick;
        return;
    }
    
    let can_buy = account.cash > 1_000_000 && current_slope > buy_threshold && slope_change > 0;
    let can_sell = account.stock > 0 && current_slope < sell_threshold && slope_change < 0;
    
    if !can_buy && !can_sell { return; }
    
    let raw_price = market.price;
    let rounded_price = ((raw_price + 500_000) / 1_000_000) * 1_000_000;
    
    if can_buy {
        let max_afford = account.cash / rounded_price;
        let buy_amount = clamp_val(position_size, 1, max_afford);
        if buy_amount > 0 {
            orders.submit_limit_buy(rounded_price, buy_amount);
            last_action_tick = current_tick;
        }
    } else if can_sell {
        let sell_amount = clamp_val(position_size, 1, account.stock);
        orders.submit_limit_sell(rounded_price, sell_amount);
        last_action_tick = current_tick;
    }
}