let initialized = false;
let last_action_tick = -50;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Lazy trader: only act every 50 ticks
    if (market.tick - last_action_tick) < 50 {
        return;
    }
    last_action_tick = market.tick;
    
    // Check order flow condition (buy_volume > 3 * sell_volume)
    // Using integer multiplication to avoid floats: 3 * sell_volume
    let three_times_sell = market.sell_volume * 3;
    if market.buy_volume > three_times_sell {
        // Join the crowd: buy with fixed amount
        let amount = 100; // Fixed share amount
        orders.submit_market_buy(amount);
    }
}