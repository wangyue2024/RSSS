// Global variables persist across ticks
let initialized = false;
let WINDOW = 20;
let FOMO_JUMP_THRESHOLD = 20000; // 2% in micro-percent (2 * 1_000_000 / 100)
let FOMO_LOOKBACK = 3;
let POSITION_LIMIT = 1000;
let last_slope = 0;
let panic_mode = false;
let panic_until_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        // Randomize window between 15-25
        WINDOW = rng.rand_int(15, 25);
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders each tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Check if still in panic cooldown
    if panic_mode && market.tick < panic_until_tick {
        // Do nothing in panic cooldown
        return;
    } else {
        panic_mode = false;
    }
    
    // FOMO check: price jump > 2% in short window
    if market.history_len() >= FOMO_LOOKBACK {
        let current_price = market.price;
        let past_price = market.history_price(FOMO_LOOKBACK - 1);
        if past_price > 0 {
            let jump_percent = (current_price - past_price) * 100_000_000 / past_price;
            if jump_percent > FOMO_JUMP_THRESHOLD {
                // FOMO trigger: market buy with 50% of available cash
                let buy_amount = (account.cash * 50 / 100) / market.price;
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                }
                panic_mode = true;
                panic_until_tick = market.tick + 10; // Cooldown for 10 ticks
                return;
            }
        }
    }
    
    // Need enough history for slope calculation
    if market.history_len() < WINDOW {
        return;
    }
    
    // Build price array for slope calculation
    let prices = [];
    let idx = 0;
    while idx < WINDOW {
        prices.push(market.history_price(idx));
        idx += 1;
    }
    
    // Calculate current slope (returns slope in micros per tick)
    let current_slope = arr_slope(prices);
    
    // Momentum logic
    if current_slope > 5000 && current_slope > last_slope * 11 / 10 {
        // Positive accelerating slope: buy aggressively
        let buy_amount = POSITION_LIMIT - account.stock;
        if buy_amount > 0 {
            // Place limit buy at current price
            orders.submit_limit_buy(market.price, buy_amount);
        }
    } else if current_slope < -10000 {
        // Panic sell if slope turns sharply negative
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        panic_mode = true;
        panic_until_tick = market.tick + 5;
    }
    
    // Update last_slope for next tick
    last_slope = current_slope;
}