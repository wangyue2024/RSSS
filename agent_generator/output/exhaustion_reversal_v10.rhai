// Global variables persist across ticks
let initialized = false;
let price_history = [];
let volume_history = [];
let last_trade_tick = -100;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders at start of tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Store current market data (delayed by saving)
    price_history.push(market.price);
    volume_history.push(market.volume);
    
    // Keep only last 10 ticks of history
    if price_history.len() > 10 {
        price_history.remove(0);
        volume_history.remove(0);
    }
    
    // Only act if we have at least 5 ticks of history
    if price_history.len() >= 5 {
        // Get data from 5 ticks ago (index 0 is oldest)
        let old_price = price_history[0];
        let old_volume = volume_history[0];
        
        // Calculate recent average volume (excluding the old tick)
        let recent_vol_sum = 0;
        let j = 1;
        while j < price_history.len() {
            recent_vol_sum += volume_history[j];
            j += 1;
        }
        let recent_avg_volume = recent_vol_sum / (price_history.len() - 1);
        
        // Exhaustion condition: price was above MA60 but volume dropped to near zero
        let volume_drop_threshold = recent_avg_volume * 10 / 100; // 10% of recent average
        let price_above_ma = old_price > market.ma_60;
        let volume_exhausted = old_volume < volume_drop_threshold;
        
        // Trading cooldown check
        let cooldown_passed = market.tick - last_trade_tick > 20;
        
        if price_above_ma && volume_exhausted && cooldown_passed {
            // Determine position size (5% of current equity)
            let equity = account.total_equity;
            let position_value = equity * 5 / 100;
            let sell_amount = position_value / market.price;
            
            // Ensure we have stock to sell
            if sell_amount > 0 && account.stock >= sell_amount {
                orders.submit_market_sell(sell_amount);
                last_trade_tick = market.tick;
            }
        }
    }
}