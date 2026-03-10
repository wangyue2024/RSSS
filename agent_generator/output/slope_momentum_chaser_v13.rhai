let initialized = false;
let stop_loss_threshold = 0;
let max_position_size = 0;
let volatility_threshold = 0;
let slope_window = 10;
let cancel_threshold_ticks = 3;
let last_slope = 0;
let panic_mode = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_threshold = -rng.rand_int(5000, 20000);
        let capital_percent = 5 * account.total_equity / 10000;
        max_position_size = capital_percent / market.price;
        if max_position_size < 1 { max_position_size = 1; }
        volatility_threshold = market.price * 3 / 100;
        slope_window = rng.rand_int(8, 15);
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel orders older than 3 ticks
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let age = market.tick - my_orders.pending_placed_tick(i);
        if age >= cancel_threshold_ticks {
            orders.submit_cancel(my_orders.pending_id(i));
        }
        i += 1;
    }
    
    // Panic sell on stop loss
    if account.unrealized_pnl < stop_loss_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        panic_mode = true;
        return;
    }
    
    // Risk aversion: skip if volatility too high
    if market.std_dev > volatility_threshold {
        return;
    }
    
    // Need enough history
    if market.history_len() < slope_window + 5 {
        return;
    }
    
    // Calculate price slope
    let price_history = [];
    let start_idx = market.history_len() - slope_window;
    let idx = start_idx;
    while idx < market.history_len() {
        price_history.push(market.history_price(idx));
        idx += 1;
    }
    
    let current_slope = arr_slope(price_history);
    
    // Determine momentum
    let is_strong_uptrend = current_slope > 1000 && current_slope > last_slope * 2;
    let slope_turned_negative = current_slope < 0 && last_slope > 0;
    
    // Panic sell if slope suddenly negative
    if slope_turned_negative && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        panic_mode = true;
        return;
    }
    
    // Reset panic mode if conditions improve
    if panic_mode && current_slope > 500 && account.stock == 0 {
        panic_mode = false;
    }
    
    // Aggressive buy on strong uptrend
    if is_strong_uptrend && !panic_mode && account.stock == 0 {
        let buy_amount = max_position_size;
        if market.buy_volume > market.sell_volume * 2 {
            buy_amount = buy_amount * 3 / 2;
        }
        
        if buy_amount > 0 {
            // Aggressive limit buy at ask
            let target_price = market.ask_price_0 + 100;
            orders.submit_limit_buy(target_price, buy_amount);
        }
    }
    
    // Take profit on weaker momentum
    if current_slope < last_slope / 2 && current_slope > 0 && account.stock > 0 {
        let sell_price = market.bid_price_0 - 100;
        orders.submit_limit_sell(sell_price, account.stock);
    }
    
    last_slope = current_slope;
}