// Global persistent state
let initialized = false;
let fair_value = 0;
let base_lot = 0;
let current_lot = 0;
let last_trade_profit = 0;
let last_avg_cost = 0;

fn on_tick() {
    if !initialized {
        // Initialize with randomization
        fair_value = 100_000_000 + rng.rand_int(-5_000_000, 5_000_000);
        base_lot = rng.rand_int(50, 200);
        current_lot = base_lot;
        last_trade_profit = 0;
        last_avg_cost = account.avg_cost;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders at start of tick
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Martingale sizing: double lot after loss
    if last_trade_profit < 0 {
        current_lot = current_lot * 2;
    } else {
        current_lot = base_lot;
    }
    
    // Track trade profit from fills in last tick
    let fill_cnt = my_orders.fill_count();
    if fill_cnt > 0 {
        let latest_fill_side = my_orders.fill_side(fill_cnt - 1);
        let latest_fill_price = my_orders.fill_price(fill_cnt - 1);
        
        if latest_fill_side == 1 { // 1 = sell
            last_trade_profit = (latest_fill_price - last_avg_cost) * my_orders.fill_amount(fill_cnt - 1);
        }
        last_avg_cost = account.avg_cost;
    }
    
    let current_price = market.price;
    
    // NEVER buy above fair value
    // Only sell when price exceeds thresholds
    if account.stock > 0 {
        if current_price > fair_value * 110 / 100 {
            // Aggressive selling
            let sell_amount = current_lot * 2;
            if sell_amount > account.stock {
                sell_amount = account.stock;
            }
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
            }
        } else if current_price > fair_value * 105 / 100 {
            // Moderate selling
            let sell_amount = current_lot;
            if sell_amount > account.stock {
                sell_amount = account.stock;
            }
            if sell_amount > 0 {
                orders.submit_market_sell(sell_amount);
            }
        }
    }
}