// Global variables persist across ticks
let initialized = false;
let prev_ma5 = 0;
let prev_ma20 = 0;
let base_lot_size = 100;
let current_lot_size = 100;
let last_trade_was_loss = false;
let last_avg_cost = 0;
let last_tick_evaluated = -100;

fn on_tick() {
    if !initialized {
        initialized = true;
        prev_ma5 = market.ma_5;
        prev_ma20 = market.ma_20;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders every tick for clean state
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Lazy trader: evaluate only every 50 ticks
    if market.tick - last_tick_evaluated < 50 { return; }
    last_tick_evaluated = market.tick;
    
    let ma5 = market.ma_5;
    let ma20 = market.ma_20;
    
    // Detect bullish crossover (MA5 crosses above MA20)
    let bullish_cross = ma5 > ma20 && prev_ma5 <= prev_ma20;
    // Detect bearish crossover (MA5 crosses below MA20)
    let bearish_cross = ma5 < ma20 && prev_ma5 >= prev_ma20;
    
    // Martingale sizing: double lot size if last trade was loss
    if last_trade_was_loss {
        current_lot_size = current_lot_size * 2;
        last_trade_was_loss = false;
    } else {
        current_lot_size = base_lot_size;
    }
    
    // Buy on bullish crossover (only if not already holding)
    if bullish_cross && account.stock == 0 {
        orders.submit_market_buy(current_lot_size);
        // Record average cost for later loss calculation
        last_avg_cost = account.avg_cost;
    }
    
    // Sell all on bearish crossover (only if holding stock)
    if bearish_cross && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        // Determine if last trade was loss
        if market.price < last_avg_cost {
            last_trade_was_loss = true;
        }
    }
    
    // Update previous values for next crossover detection
    prev_ma5 = ma5;
    prev_ma20 = ma20;
}