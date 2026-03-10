let price_buffer = [];
let volume_buffer = [];
let signal_triggered = false;
let position_size = 0;
let entry_price = 0;
let cooldown = 0;
let position_active = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Cancel existing pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    // Update buffers with current data
    price_buffer.push(market.price);
    volume_buffer.push(market.volume);
    
    // Keep only last 5 ticks
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
        volume_buffer.remove(0);
    }
    
    // Reduce cooldown
    if cooldown > 0 {
        cooldown = cooldown - 1;
    }
    
    // Only analyze if we have enough history
    if price_buffer.len() < 5 || volume_buffer.len() < 5 {
        return;
    }
    
    // Get 5-tick old data (index 0)
    let old_price = price_buffer[0];
    let old_volume = volume_buffer[0];
    
    // Exhaustion detection: price above MA60 but volume dropped to near zero
    let volume_threshold = 1000; // Minimal volume in shares
    let ma60 = market.ma_60;
    
    // Check if old price was significantly above MA60 (1% threshold)
    let price_above_ma = false;
    if ma60 > 0 {
        let threshold = ma60 * 101 / 100; // 1% above
        price_above_ma = old_price > threshold;
    }
    
    let low_volume = old_volume < volume_threshold;
    
    // Exhaustion signal
    if price_above_ma && low_volume && cooldown == 0 && !position_active {
        signal_triggered = true;
    }
    
    // Execute short position if signal triggered
    if signal_triggered {
        signal_triggered = false;
        cooldown = 20;
        
        // Calculate position size (5% of equity)
        let equity = account.total_equity;
        if equity > 0 {
            let target_value = equity * 5 / 100;
            if market.price > 0 {
                position_size = target_value / market.price;
                position_size = clamp_val(position_size, 1, 10000);
                
                // Submit market sell order
                orders.submit_market_sell(position_size);
                position_active = true;
                entry_price = market.price;
            }
        }
    }
    
    // Exit position logic
    if position_active {
        // Stop loss at 2% above entry
        let stop_loss_price = entry_price * 102 / 100;
        
        // Take profit at 1% below entry
        let take_profit_price = entry_price * 99 / 100;
        
        // Check exit conditions
        if market.price >= stop_loss_price || market.price <= take_profit_price {
            // Close position with market buy
            if account.stock < position_size {
                orders.submit_market_buy(account.stock);
            } else {
                orders.submit_market_buy(position_size);
            }
            position_active = false;
            position_size = 0;
            cooldown = 10;
        }
    }
}