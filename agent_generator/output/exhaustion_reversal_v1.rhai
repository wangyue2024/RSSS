let initialized = false;
let lookback_ticks = 20;
let volume_threshold_pct = 10;

fn on_tick() {
    if !initialized {
        initialized = true;
        // Set volume threshold to 10% (100 = 1%, 1000 = 10%, 10000 = 100%)
        volume_threshold_pct = 1000;
    }
    
    if !market.trading_enabled { return; }
    
    // Lazy trader: only evaluate every 50 ticks
    if market.tick % 50 != 0 { return; }
    
    // Cancel all pending orders on evaluation ticks
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Check for exhaustion reversal signal
    // 1. Price is above long-term MA (climax top)
    let price_above_ma = market.price > market.ma_60;
    
    // 2. Current volume drops to near zero (less than threshold% of recent average)
    let history_len = market.history_len();
    let usable_lookback = if lookback_ticks > history_len { history_len } else { lookback_ticks };
    
    let total_volume = 0;
    let j = 0;
    while j < usable_lookback {
        total_volume += market.history_volume(j);
        j += 1;
    }
    
    let avg_volume = if usable_lookback > 0 { total_volume / usable_lookback } else { 0 };
    let threshold_volume = avg_volume * volume_threshold_pct / 10000;
    
    let volume_exhausted = market.volume < threshold_volume && market.volume > 0;
    
    // Execute contrarian trade if both conditions met
    if price_above_ma && volume_exhausted {
        // Initiate short/sell position (market sell for immediate execution)
        if account.stock > 0 {
            let sell_amount = account.stock;
            orders.submit_market_sell(sell_amount);
        }
    }
}