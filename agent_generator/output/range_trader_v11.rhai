let initialized = false;
let base_position = 10;
let panic_buy_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_position = rng.rand_int(5, 25);
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders every tick
    let pending_cnt = my_orders.pending_count();
    let idx = 0;
    while idx < pending_cnt {
        let oid = my_orders.pending_id(idx);
        orders.submit_cancel(oid);
        idx += 1;
    }
    
    // FOMO panic buy check: price jump > 2% in last 5 ticks
    if market.history_len() > 5 {
        let current_price = market.price;
        let past_price = market.history_price(5);
        let change_bps = (current_price - past_price) * 10000 / past_price;
        if change_bps > 200 && !panic_buy_triggered {
            panic_buy_triggered = true;
            let buy_amount = (account.cash / 2) / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
            }
            return;
        }
    }
    
    // Reset panic flag if condition not met
    panic_buy_triggered = false;
    
    // Range trading logic
    let spread = market.high_20 - market.low_20;
    let price_threshold = market.price * 1 / 100; // 1% of current price
    
    let position_multiplier = 1;
    if spread < price_threshold {
        position_multiplier = 2;
    }
    
    let trade_amount = base_position * position_multiplier;
    
    // Place limit buy near low_20 (5% above low)
    let buy_price = market.low_20 + (spread * 5 / 100);
    if buy_price > 0 && account.cash >= buy_price * trade_amount {
        orders.submit_limit_buy(buy_price, trade_amount);
    }
    
    // Place limit sell near high_20 (5% below high)
    let sell_price = market.high_20 - (spread * 5 / 100);
    if sell_price > 0 && account.stock >= trade_amount {
        orders.submit_limit_sell(sell_price, trade_amount);
    }
}