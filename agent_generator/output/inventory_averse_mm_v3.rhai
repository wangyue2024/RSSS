let initialized = false;
let base_lot_size = 100;
let current_lot_size = base_lot_size;
let last_trade_was_loss = false;
let last_trade_price = 0;
let last_trade_side = -1;
let current_buy_order_id = -1;
let current_buy_order_placed_tick = -1;
let current_sell_order_id = -1;
let current_sell_order_placed_tick = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    // Check if current orders are still pending
    if current_buy_order_id != -1 {
        let found = false;
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count && !found {
            if my_orders.pending_id(i) == current_buy_order_id {
                found = true;
            }
            i += 1;
        }
        if !found {
            current_buy_order_id = -1;
            current_buy_order_placed_tick = -1;
        }
    }
    
    if current_sell_order_id != -1 {
        let found = false;
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count && !found {
            if my_orders.pending_id(i) == current_sell_order_id {
                found = true;
            }
            i += 1;
        }
        if !found {
            current_sell_order_id = -1;
            current_sell_order_placed_tick = -1;
        }
    }
    
    // Process fills to update last trade info
    let fill_count = my_orders.fill_count();
    let i = 0;
    while i < fill_count {
        let fill_price = my_orders.fill_price(i);
        let fill_side = my_orders.fill_side(i);
        last_trade_price = fill_price;
        last_trade_side = fill_side;
        last_trade_was_loss = false;
        
        // Invalidate corresponding order ID if filled
        let fill_id = my_orders.fill_id(i);
        if fill_id == current_buy_order_id {
            current_buy_order_id = -1;
            current_buy_order_placed_tick = -1;
        }
        if fill_id == current_sell_order_id {
            current_sell_order_id = -1;
            current_sell_order_placed_tick = -1;
        }
        i += 1;
    }
    
    // Determine if last trade was a loss
    if last_trade_side == 0 && market.price < last_trade_price {
        last_trade_was_loss = true;
    } else if last_trade_side == 1 && market.price > last_trade_price {
        last_trade_was_loss = true;
    }
    
    // Martingale sizing
    if last_trade_was_loss {
        current_lot_size = current_lot_size * 2;
        if current_lot_size > 1600 {
            current_lot_size = 1600;
        }
    } else {
        current_lot_size = base_lot_size;
    }
    
    // Cancel orders older than 3 ticks
    if current_buy_order_id != -1 && (current_tick - current_buy_order_placed_tick >= 3) {
        orders.submit_cancel(current_buy_order_id);
        current_buy_order_id = -1;
        current_buy_order_placed_tick = -1;
    }
    
    if current_sell_order_id != -1 && (current_tick - current_sell_order_placed_tick >= 3) {
        orders.submit_cancel(current_sell_order_id);
        current_sell_order_id = -1;
        current_sell_order_placed_tick = -1;
    }
    
    // Inventory limits - stop trading if too extreme
    if account.stock > 2000 || account.stock < -2000 {
        return;
    }
    
    // Calculate inventory skew
    let base_spread = 10_000;
    let inventory_skew = account.stock;
    if inventory_skew > 1000 { inventory_skew = 1000; }
    if inventory_skew < -1000 { inventory_skew = -1000; }
    
    let bid_spread = base_spread * (1000 + inventory_skew) / 1000;
    let ask_spread = base_spread * (1000 - inventory_skew) / 1000;
    
    // Minimum spread
    let min_spread = 100;
    if bid_spread < min_spread { bid_spread = min_spread; }
    if ask_spread < min_spread { ask_spread = min_spread; }
    
    // Calculate prices with off-by-one pumper for bid
    let bid_price = market.price - bid_spread + 1;
    let ask_price = market.price + ask_spread;
    
    // Place buy order if needed
    if current_buy_order_id == -1 && account.stock < 2000 {
        current_buy_order_id = orders.submit_limit_buy(bid_price, current_lot_size);
        current_buy_order_placed_tick = current_tick;
    }
    
    // Place sell order if needed
    if current_sell_order_id == -1 && account.stock > -2000 {
        current_sell_order_id = orders.submit_limit_sell(ask_price, current_lot_size);
        current_sell_order_placed_tick = current_tick;
    }
}