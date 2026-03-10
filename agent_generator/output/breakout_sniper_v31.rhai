let initialized = false;
let stop_loss_ticks = 5;
let buy_aggression = 50;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_ticks = rng.rand_int(3, 8);
        buy_aggression = rng.rand_int(30, 70);
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders at start of each tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    let avg_cost = account.avg_cost;
    let position = account.stock;
    let cash = account.cash;
    
    // Buy logic: breakout above 20-tick high
    if current_price > market.high_20 && cash > 100_000 {
        // Round to nearest whole dollar (1_000_000 micros)
        let rounded_price = ((current_price + 500_000) / 1_000_000) * 1_000_000;
        // Use aggressive buy with percentage of cash
        let buy_amount_micros = cash * buy_aggression / 100;
        let buy_shares = buy_amount_micros / rounded_price;
        
        if buy_shares > 0 {
            orders.submit_limit_buy(rounded_price, buy_shares);
        }
    }
    
    // Sell logic: only sell at profit (price > avg_cost)
    if position > 0 && current_price > avg_cost {
        // Calculate stop-loss price (static ticks below avg_cost)
        let stop_price = avg_cost - (stop_loss_ticks * 10);
        // Round to nearest whole dollar
        let rounded_stop = ((stop_price + 500_000) / 1_000_000) * 1_000_000;
        
        // Only place sell if rounded price is above avg_cost (no loss)
        if rounded_stop > avg_cost {
            orders.submit_limit_sell(rounded_stop, position);
        }
    }
}