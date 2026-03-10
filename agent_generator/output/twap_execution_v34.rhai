// Global variables persist across ticks automatically
let initialized = false;
let target_position = 50000;
let lot_size = 0;
let interval = 10;
let last_action_tick = -100;

fn on_tick() {
    if !initialized {
        initialized = true;
        // Initialize lot_size to less than 5% of total capital in share terms
        let capital_micros = account.total_equity;
        let five_percent_capital = capital_micros * 5 / 100;
        let max_shares = five_percent_capital / market.price;
        if max_shares < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel any pending limit orders (safety)
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Risk-averse: refuse to trade if volatility (std dev) is high (>2% of price)
    let volatility_threshold = market.price * 2 / 100;
    if market.std_dev > volatility_threshold {
        return;
    }
    
    // Check if we have reached target position
    let current_position = account.stock;
    if current_position >= target_position {
        return;
    }
    
    // Execute a slice every 'interval' ticks
    let ticks_since_last = market.tick - last_action_tick;
    if ticks_since_last >= interval {
        let remaining_to_target = target_position - current_position;
        let buy_amount = remaining_to_target;
        if buy_amount > lot_size {
            buy_amount = lot_size;
        }
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
            last_action_tick = market.tick;
        }
    }
}