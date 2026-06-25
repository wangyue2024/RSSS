let initialized = false;
let position_size = 100;
let volume_window = 20;
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        position_size = rng.rand_int(50, 200);
    }
    
    if !market.trading_enabled { return; }
    
    // Morning Person: only active first 20% of session
    if market.tick >= market.total_ticks * 20 / 100 {
        return;
    }
    
    // Cancel all pending orders each tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // FOMO condition: price jumps >2% in short window (5 ticks)
    let short_window = 5;
    let fomo_price_jump = 0;
    if market.tick >= short_window {
        let past_price = market.history_price(short_window);
        if past_price > 0 {
            let price_change = (market.price - past_price) * 100 / past_price;
            if price_change > 2 {
                fomo_triggered = true;
            }
        }
    }
    
    if fomo_triggered {
        // Abandon strategy, market buy immediately
        let buy_amount = account.cash * 30 / 100 / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        return;
    }
    
    // Core exhaustion reversal logic
    if market.price > market.ma_60 && market.ma_60 > 0 {
        // Calculate average volume of last volume_window ticks
        let hist_len = market.history_len();
        let window = if hist_len < volume_window { hist_len } else { volume_window };
        let total_vol = 0;
        let j = 0;
        while j < window {
            total_vol += market.history_volume(j);
            j += 1;
        }
        
        let avg_vol = if window > 0 { total_vol / window } else { 1 };
        
        // Volume drops to near zero (less than 5% of average)
        if market.volume > 0 && market.volume * 100 / avg_vol < 5 {
            // Initiate short/sell position
            let sell_price = market.bid_price_0;
            if sell_price > 0 && account.stock >= position_size {
                // Off-by-One Pumper: subtract 1 micro to jump ahead in sell queue
                orders.submit_limit_sell(sell_price - 1, position_size);
            }
        }
    }
}