let initialized = false;
let base_lot_size = 0;
let current_lot_size = 0;
let last_trade_was_loss = false;
let last_trade_avg_cost = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(5000, 25000);
        current_lot_size = base_lot_size;
        last_trade_avg_cost = 0;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Check last trade for loss
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let last_fill_idx = fill_cnt - 1;
        let last_fill_side = my_orders.fill_side(last_fill_idx);
        let last_fill_price = my_orders.fill_price(last_fill_idx);
        
        if last_trade_avg_cost != 0 {
            if (last_fill_side == 1 && last_fill_price < last_trade_avg_cost) || (last_fill_side == -1 && last_fill_price > last_trade_avg_cost) {
                last_trade_was_loss = true;
            } else {
                last_trade_was_loss = false;
            }
        }
        
        // Update average cost tracking (simplified)
        last_trade_avg_cost = last_fill_price;
    }
    
    // Martingale sizing
    if last_trade_was_loss {
        current_lot_size = current_lot_size * 2;
    } else {
        current_lot_size = base_lot_size;
    }
    
    // Calculate range
    let range_low = market.low_20;
    let range_high = market.high_20;
    let spread = range_high - range_low;
    
    if spread <= 0 { return; }
    
    // Adjust position size based on spread (narrow range = larger position)
    let spread_factor = 1_000_000 * 100 / spread;
    let spread_factor_clamped = clamp_val(spread_factor, 100, 500);
    let adjusted_lot = current_lot_size * spread_factor_clamped / 100;
    
    // Risk-seeking: use up to 50% of cash
    let max_by_cash = account.cash * 50 / (100 * market.price);
    let position_size = clamp_val(adjusted_lot, 100, max_by_cash);
    
    // Place orders near range boundaries
    let buy_price = range_low + spread * 5 / 100;
    let sell_price = range_high - spread * 5 / 100;
    
    if position_size > 0 {
        orders.submit_limit_buy(buy_price, position_size);
        orders.submit_limit_sell(sell_price, position_size);
    }
}