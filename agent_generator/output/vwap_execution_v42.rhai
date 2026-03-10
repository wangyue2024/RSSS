let initialized = false;
let target_shares = 0;
let bought_so_far = 0;
let last_decision_tick = 0;
let price_history = [];
let fomo_triggered = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        target_shares = (account.cash / market.price) * 30 / 100;
        last_decision_tick = market.tick;
    }
    
    price_history.push(market.price);
    if price_history.len() > 10 {
        price_history.remove(0);
    }
    
    if price_history.len() >= 5 {
        let old_price = price_history[0];
        let new_price = price_history[price_history.len() - 1];
        let price_change = abs_val(new_price - old_price) * 10000 / old_price;
        if price_change > 200 && !fomo_triggered {
            fomo_triggered = true;
            let remaining = target_shares - bought_so_far;
            if remaining > 0 {
                orders.submit_market_buy(remaining);
            }
            return;
        }
    }
    
    if market.tick % 50 != 0 {
        return;
    }
    
    fomo_triggered = false;
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let fill_count = my_orders.fill_count();
    i = 0;
    while i < fill_count {
        let fill_side = my_orders.fill_side(i);
        let fill_amount = my_orders.fill_amount(i);
        if fill_side == 0 {
            bought_so_far += fill_amount;
        }
        i += 1;
    }
    
    if bought_so_far >= target_shares {
        return;
    }
    
    let remaining = target_shares - bought_so_far;
    if remaining <= 0 {
        return;
    }
    
    let recent_volume = 0;
    let history_len = market.history_len();
    let lookback = if history_len < 20 { history_len } else { 20 };
    let j = 0;
    while j < lookback {
        recent_volume += market.history_volume(j);
        j += 1;
    }
    
    let avg_volume = if lookback > 0 { recent_volume / lookback } else { 1000 };
    let volume_ratio = if avg_volume > 0 { market.volume * 100 / avg_volume } else { 100 };
    
    let max_slice = if volume_ratio > 150 {
        remaining * 30 / 100
    } else if volume_ratio > 100 {
        remaining * 20 / 100
    } else {
        remaining * 10 / 100
    };
    
    let slice = clamp_val(max_slice, 100, remaining);
    
    if slice > 0 {
        let spread = market.ask_price_0 - market.bid_price_0;
        let limit_price = market.bid_price_0 + spread * 30 / 100;
        orders.submit_limit_buy(limit_price, slice);
    }
}