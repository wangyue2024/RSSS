let lot_size = 100;
let last_buy_cost = 0;
let order_ticks_map = [];
let last_trade_loss = false;
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        lot_size = 100;
        last_buy_cost = 0;
        order_ticks_map = [];
        last_trade_loss = false;
    }
    
    if !market.trading_enabled { return; }
    
    if market.total_ticks < 20 { return; }
    
    let low = market.low_20;
    let high = market.high_20;
    let spread = high - low;
    
    if spread <= 0 { return; }
    
    let mid = low + spread / 2;
    let buy_offset = spread * 10 / 100;
    let sell_offset = spread * 10 / 100;
    let buy_price = low + buy_offset;
    let sell_price = high - sell_offset;
    
    if sell_price <= buy_price {
        buy_price = low;
        sell_price = high;
    }
    
    if last_trade_loss {
        lot_size = lot_size * 2;
        if lot_size > 10000 {
            lot_size = 10000;
        }
    } else {
        lot_size = 100;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        let placed_tick = my_orders.pending_placed_tick(i);
        
        let age = market.tick - placed_tick;
        if age >= 3 {
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if account.stock == 0 {
        orders.submit_limit_buy(buy_price, lot_size);
        orders.submit_limit_sell(sell_price, lot_size);
    } else if account.stock > 0 {
        orders.submit_limit_sell(sell_price, account.stock);
        orders.submit_limit_buy(buy_price, lot_size);
    } else {
        let short_pos = -account.stock;
        orders.submit_limit_buy(buy_price, short_pos);
        orders.submit_limit_sell(sell_price, lot_size);
    }
    
    let fill_count = my_orders.fill_count();
    i = 0;
    while i < fill_count {
        let fill_side = my_orders.fill_side(i);
        let fill_price = my_orders.fill_price(i);
        
        if fill_side == 0 {
            last_buy_cost = fill_price;
        } else if fill_side == 1 {
            if last_buy_cost > 0 {
                let profit = fill_price - last_buy_cost;
                last_trade_loss = profit <= 0;
            }
        }
        i += 1;
    }
}