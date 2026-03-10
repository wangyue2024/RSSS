let initialized = false;
let last_prices = [];
let round_base = 1_000_000;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders at start of each tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    // Update price buffer for FOMO detection (last 5 ticks)
    last_prices.push(market.price);
    if last_prices.len() > 5 {
        last_prices.remove(0);
    }
    
    // FOMO: price jumped >2% in last 5 ticks
    if last_prices.len() == 5 {
        let old_price = last_prices[0];
        let change = (market.price - old_price) * 10000 / old_price;
        if change > 200 {  // 2% = 200 basis points
            // Market buy immediately
            let buy_amount = 100;
            if account.cash >= market.price * buy_amount {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }
    
    // Core exhaustion reversal logic
    let avg_volume_20 = 0;
    if market.history_len() >= 20 {
        let volumes = [];
        let j = 0;
        while j < 20 {
            volumes.push(market.history_volume(j));
            j += 1;
        }
        avg_volume_20 = arr_mean(volumes);
    }
    
    let volume_near_zero = false;
    if avg_volume_20 > 0 {
        // current volume < 10% of 20-period average
        volume_near_zero = market.volume * 100 < avg_volume_20 * 10;
    }
    
    let price_above_ma = market.price > market.ma_60;
    
    // Exhaustion condition
    if price_above_ma && volume_near_zero && account.stock > 0 {
        // Stubborn Holder: only sell if price > avg_cost
        if market.price > account.avg_cost {
            // Round to nearest dollar
            let raw_price = market.price;
            let remainder = raw_price % round_base;
            let rounded_price = if remainder >= round_base / 2 {
                raw_price - remainder + round_base
            } else {
                raw_price - remainder
            };
            
            orders.submit_limit_sell(rounded_price, account.stock);
        }
    }
}