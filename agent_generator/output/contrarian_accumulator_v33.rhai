let initialized = false;
let base_lot = 0;
let current_lot = 0;
let last_trade_was_loss = false;
let last_decision_tick = -50;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot = rng.rand_int(20, 100);
        current_lot = base_lot;
    }
    
    if !market.trading_enabled { return; }
    
    let tick = market.tick;
    
    // High-frequency canceler: cancel orders older than 2 ticks (>=3)
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_at = my_orders.pending_placed_tick(i);
        if tick - placed_at >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Lazy trader: only evaluate every 50 ticks
    if tick - last_decision_tick < 50 { return; }
    last_decision_tick = tick;
    
    // Martingale sizing update
    if account.stock > 0 {
        // Check if we're at a loss (current price below average cost)
        if market.price < account.avg_cost {
            current_lot = base_lot * 2;
        } else {
            current_lot = base_lot;
        }
    } else {
        current_lot = base_lot;
    }
    
    // Cancel all remaining pending orders (we're making new decisions)
    let pending_cnt2 = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt2 {
        let oid = my_orders.pending_id(j);
        orders.submit_cancel(oid);
        j += 1;
    }
    
    let rsi = market.rsi_14;
    
    // Oversold: buy aggressively with limit below current price
    if rsi < 3000 && market.price > 0 {
        // Calculate 1% below current price
        let buy_price = market.price * 99 / 100;
        let amount = current_lot;
        // Ensure we have enough cash
        let max_buyable = account.cash / buy_price;
        if max_buyable > 0 {
            if amount > max_buyable {
                amount = max_buyable;
            }
            if amount > 0 {
                orders.submit_limit_buy(buy_price, amount);
            }
        }
    }
    // Overbought: sell
    else if rsi > 7000 && account.stock > 0 {
        // Calculate 1% above current price
        let sell_price = market.price * 101 / 100;
        let amount = current_lot;
        if amount > account.stock {
            amount = account.stock;
        }
        if amount > 0 {
            orders.submit_limit_sell(sell_price, amount);
        }
    }
}