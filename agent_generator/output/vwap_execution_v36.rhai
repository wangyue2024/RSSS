// Global variables persist across ticks
let initialized = false;
let lot_size = 0;
let price_history = [];
let volume_history = [];
let decision_delay = 5;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Initialize once
    if !initialized {
        initialized = true;
        // Risk-averse: lot size less than 5% of total capital
        let max_capital_use = account.total_equity * 5 / 100;
        // Minimum of 1 share
        if max_capital_use > 0 && market.price > 0 {
            let max_shares = max_capital_use / market.price;
            if max_shares > 0 {
                lot_size = rng.rand_int(1, max_shares);
            } else {
                lot_size = 1;
            }
        } else {
            lot_size = 1;
        }
    }
    
    // Cancel all pending orders each tick
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Store current data
    price_history.push(market.price);
    volume_history.push(market.volume);
    
    // Keep only last 5 ticks
    if price_history.len() > decision_delay {
        price_history.remove(0);
        volume_history.remove(0);
    }
    
    // Need enough history to make decisions
    if price_history.len() < decision_delay {
        return;
    }
    
    // Use data from 5 ticks ago (oldest in our array)
    let delayed_price = price_history[0];
    let delayed_volume = volume_history[0];
    
    // Risk check: refuse to trade if std_dev is high (greater than 2% of price)
    let risk_threshold = delayed_price * 2 / 100;
    if market.std_dev > risk_threshold {
        return;
    }
    
    // Calculate dynamic slice size based on recent volume
    let recent_avg_volume = arr_mean(volume_history);
    let volume_ratio = if recent_avg_volume > 0 { delayed_volume * 100 / recent_avg_volume } else { 100 };
    
    // Scale buy amount based on volume: more volume = buy more
    let scaled_amount = if volume_ratio > 100 {
        lot_size * volume_ratio / 100
    } else {
        lot_size * 50 / 100  // Buy less when volume is low
    };
    
    // Ensure minimum of 1 share
    let buy_amount = if scaled_amount < 1 { 1 } else { scaled_amount };
    
    // Stubborn holder: only sell if price > avg_cost
    let sell_amount = if account.stock > 0 && delayed_price > account.avg_cost {
        // Sell up to half of position
        let max_sell = account.stock / 2;
        if max_sell < 1 { 0 } else { max_sell }
    } else {
        0
    };
    
    // Place orders if we have enough cash/stock
    if buy_amount > 0 && account.cash >= delayed_price * buy_amount {
        orders.submit_limit_buy(delayed_price, buy_amount);
    }
    
    if sell_amount > 0 && account.stock >= sell_amount {
        orders.submit_limit_sell(delayed_price, sell_amount);
    }
}