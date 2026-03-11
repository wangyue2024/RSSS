let initialized = false;
let base_lot_size = 0;
let delayed_prices = [];
let last_position = 0;
let last_avg_cost = 0;
let current_lot = 0;
let last_trade_profit = true;
let order_placement_ticks = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(50, 200);
        current_lot = base_lot_size;
        last_position = 0;
        last_avg_cost = 0;
        last_trade_profit = true;
        order_placement_ticks = [];
        delayed_prices = [];
        return;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders every tick (high-frequency canceler)
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    // Track fills for martingale sizing
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let new_position = account.stock;
        let new_avg_cost = account.avg_cost;
        
        // Determine if last trade was loss (comparing position change)
        if last_position != 0 && new_position == 0 {
            // Position closed
            let exit_price = market.price;
            let entry_value = last_avg_cost * last_position.abs();
            let exit_value = exit_price * last_position.abs();
            last_trade_profit = exit_value > entry_value;
            
            // Martingale: double lot if loss, reset if profit
            if !last_trade_profit {
                current_lot = current_lot * 2;
            } else {
                current_lot = base_lot_size;
            }
            current_lot = clamp_val(current_lot, base_lot_size, base_lot_size * 16);
        }
        
        last_position = new_position;
        last_avg_cost = new_avg_cost;
    }
    
    // Delayed reaction: store current price
    delayed_prices.push(market.price);
    if delayed_prices.len() > 5 {
        delayed_prices.remove(0);
    }
    
    // Only act if we have 5-ticks-old data
    if delayed_prices.len() >= 5 {
        let price_5_ticks_ago = delayed_prices[0];
        
        // Use range from 5 ticks ago (simulated - we use current range as proxy)
        let range_high = market.high_20;
        let range_low = market.low_20;
        let spread = range_high - range_low;
        
        // Increase position size if narrow range
        let range_adjusted_lot = current_lot;
        if spread < 50_000 {
            range_adjusted_lot = current_lot * 3 / 2;
        }
        
        // Place limit orders near range boundaries
        let buy_price = range_low + spread * 5 / 100;
        let sell_price = range_high - spread * 5 / 100;
        
        // Ensure prices are valid
        if buy_price > 0 && sell_price > buy_price && market.price > 0 {
            orders.submit_limit_buy(buy_price, range_adjusted_lot);
            orders.submit_limit_sell(sell_price, range_adjusted_lot);
            
            // Track when we placed these orders
            order_placement_ticks.push(market.tick);
        }
    }
    
    // Clean old order placement ticks
    let j = 0;
    while j < order_placement_ticks.len() {
        if market.tick - order_placement_ticks[j] > 10 {
            order_placement_ticks.remove(j);
        } else {
            j += 1;
        }
    }
}