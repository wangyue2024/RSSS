let initialized = false;
let base_lot_size = 100;
let prev_ma5 = 0;
let prev_ma20 = 0;
let last_trade_loss = false;
let pending_tracker = #{}; 

fn on_tick() {
    if !initialized {
        initialized = true;
        prev_ma5 = market.ma_5;
        prev_ma20 = market.ma_20;
    }

    if !market.trading_enabled { return; }

    // High-Frequency Canceler: Cancel pending orders older than 3 ticks
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }

    let current_ma5 = market.ma_5;
    let current_ma20 = market.ma_20;

    // Check for MA crossover signals
    let buy_signal = prev_ma5 <= prev_ma20 && current_ma5 > current_ma20;
    let sell_signal = prev_ma5 >= prev_ma20 && current_ma5 < current_ma20;

    // Martingale sizing
    let current_lot_size = if last_trade_loss { base_lot_size * 2 } else { base_lot_size };

    // Buy logic on golden cross
    if buy_signal {
        // Submit market buy with martingale sizing
        orders.submit_market_buy(current_lot_size);
    }

    // Sell logic on death cross (only if price > avg_cost)
    if sell_signal && market.price > account.avg_cost && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        
        // Check if last trade was loss by comparing price to average cost
        if market.price < account.avg_cost {
            last_trade_loss = true;
        } else {
            last_trade_loss = false;
        }
    }

    // Update previous MA values for next tick
    prev_ma5 = current_ma5;
    prev_ma20 = current_ma20;
}