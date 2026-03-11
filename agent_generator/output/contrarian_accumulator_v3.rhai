let price_buffer = [];
let rsi_buffer = [];
let last_trade_profit = 0;
let lot_size = 20;
let pending_order_id = -1;
let pending_order_age = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    // Update delay buffers
    price_buffer.push(market.price);
    rsi_buffer.push(market.rsi_14);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
        rsi_buffer.remove(0);
    }
    
    // Cancel orders older than 3 ticks
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        let age = market.tick - my_orders.pending_placed_tick(i);
        if age >= 3 {
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    // Process fills to track profit/loss
    let fill_count = my_orders.fill_count();
    let j = 0;
    while j < fill_count {
        let fill_side = my_orders.fill_side(j);
        let fill_price = my_orders.fill_price(j);
        if fill_side == 0 {  // Buy
            let current_value = market.price * my_orders.fill_amount(j);
            let cost = fill_price * my_orders.fill_amount(j);
            last_trade_profit = current_value - cost;
        } else {  // Sell
            last_trade_profit = (fill_price - account.avg_cost) * my_orders.fill_amount(j);
        }
        j += 1;
    }
    
    // Adjust lot size based on last trade result
    if last_trade_profit < 0 {
        lot_size = lot_size * 2;
        if lot_size > 100 {
            lot_size = 100;
        }
    } else {
        lot_size = 20;
    }
    
    // Only trade with 5-tick delayed data
    if price_buffer.len() < 5 { return; }
    
    let delayed_rsi = rsi_buffer[0];
    let delayed_price = price_buffer[0];
    
    // Check for oversold condition (buy)
    if delayed_rsi < 3000 && account.cash > delayed_price * lot_size {
        let target_price = delayed_price * 99 / 100;  // 1% below delayed price
        if my_orders.pending_count() == 0 {
            orders.submit_limit_buy(target_price, lot_size);
        }
    }
    
    // Check for overbought condition (sell)
    if delayed_rsi > 7000 && account.stock >= lot_size {
        let target_price = delayed_price * 101 / 100;  // 1% above delayed price
        if my_orders.pending_count() == 0 {
            orders.submit_limit_sell(target_price, lot_size);
        }
    }
}