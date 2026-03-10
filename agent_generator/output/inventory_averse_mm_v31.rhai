let initialized = false;
let base_lot_size = 100;
let current_lot_size = 100;
let last_trade_profit = 0;
let last_inventory = 0;
let martingale_factor = 1;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_lot_size = rng.rand_int(80, 120);
        current_lot_size = base_lot_size;
    }
    
    if !market.trading_enabled { return; }
    
    // Cancel all pending orders
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    // Check fills from last tick to track PnL
    let fill_count = my_orders.fill_count();
    if fill_count > 0 {
        let last_fill_idx = fill_count - 1;
        let fill_side = my_orders.fill_side(last_fill_idx);
        let fill_price = my_orders.fill_price(last_fill_idx);
        
        if fill_side == 0 { // Buy fill
            if market.price < fill_price {
                last_trade_profit = -1;
            } else {
                last_trade_profit = 1;
            }
        } else { // Sell fill
            if market.price > fill_price {
                last_trade_profit = -1;
            } else {
                last_trade_profit = 1;
            }
        }
        
        // Martingale sizing
        if last_trade_profit == -1 {
            martingale_factor = martingale_factor * 2;
            if martingale_factor > 16 { martingale_factor = 16; }
        } else {
            martingale_factor = 1;
        }
        current_lot_size = base_lot_size * martingale_factor;
        if current_lot_size > 1600 { current_lot_size = 1600; }
    }
    
    // Inventory-aware quoting
    let inventory = account.stock;
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let base_spread = 50_000; // 5 cents
    
    let bid_distance = base_spread;
    let ask_distance = base_spread;
    
    if inventory > 1000 {
        // High inventory: sell aggressively, buy conservatively
        bid_distance = base_spread * 3 / 2;
        ask_distance = base_spread / 2;
    } else if inventory <= 0 {
        // Low/negative inventory: buy aggressively, sell conservatively
        bid_distance = base_spread / 2;
        ask_distance = base_spread * 3 / 2;
    }
    
    // Clamp distances
    if bid_distance < 10_000 { bid_distance = 10_000; }
    if ask_distance < 10_000 { ask_distance = 10_000; }
    if bid_distance > 200_000 { bid_distance = 200_000; }
    if ask_distance > 200_000 { ask_distance = 200_000; }
    
    // Calculate quote prices
    let bid_price = mid_price - bid_distance;
    let ask_price = mid_price + ask_distance;
    
    // Ensure prices don't cross market
    if bid_price >= market.ask_price_0 {
        bid_price = market.ask_price_0 - 10_000;
    }
    if ask_price <= market.bid_price_0 {
        ask_price = market.bid_price_0 + 10_000;
    }
    
    // Place orders if we have enough cash/stock
    if bid_price > 0 && account.cash >= bid_price * current_lot_size {
        orders.submit_limit_buy(bid_price, current_lot_size);
    }
    
    if ask_price > 0 && account.stock >= current_lot_size {
        orders.submit_limit_sell(ask_price, current_lot_size);
    }
    
    last_inventory = inventory;
}