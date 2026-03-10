// Global variables persist across ticks automatically
let initialized = false;
let lot_size = 0;

fn round_to_dollar(price) {
    let round_to = 1_000_000;
    let half = 500_000;
    ((price + half) / round_to) * round_to
}

fn on_tick() {
    if !initialized {
        initialized = true;
        // Initialize large lot size: up to 50% of cash
        let cash = account.cash;
        if cash > 0 {
            let max_cash_to_risk = cash * 50 / 100;
            let price = market.price;
            if price > 0 {
                lot_size = max_cash_to_risk / price;
                if lot_size < 1 {
                    lot_size = 1;
                }
            }
        }
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel orders older than 3 ticks
    let current_tick = market.tick;
    let i = 0;
    while i < my_orders.pending_count() {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Calculate Bollinger Bands
    let middle = market.ma_20;
    let std = market.std_dev;
    let upper_raw = middle + 2 * std;
    let lower_raw = middle - 2 * std;
    
    // Round to nearest dollar (1,000,000 micros)
    let upper_price = round_to_dollar(upper_raw);
    let lower_price = round_to_dollar(lower_raw);
    
    // Check for existing pending orders at these prices
    let has_buy = false;
    let has_sell = false;
    
    let j = 0;
    while j < my_orders.pending_count() {
        let price = my_orders.pending_price(j);
        let side = my_orders.pending_side(j);
        if price == lower_price && side == 0 {
            has_buy = true;
        }
        if price == upper_price && side == 1 {
            has_sell = true;
        }
        j += 1;
    }
    
    // Place new orders if we don't have them already
    if !has_buy && lot_size > 0 {
        orders.submit_limit_buy(lower_price, lot_size);
    }
    
    if !has_sell && account.stock >= lot_size && lot_size > 0 {
        orders.submit_limit_sell(upper_price, lot_size);
    }
}