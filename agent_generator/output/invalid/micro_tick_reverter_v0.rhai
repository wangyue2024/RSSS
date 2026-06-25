let TICK_SIZE = 10_000;
let BASE_LOT = 100;
let MAX_MULTIPLIER = 8;

let initialized = false;
let last_price = 0;
let multiplier = 1;
let entry_price = 0;
let entry_side = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_price = market.price;
        return;
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let fill_count = my_orders.fill_count();
    i = 0;
    while i < fill_count {
        let fill_side = my_orders.fill_side(i);
        let fill_price = my_orders.fill_price(i);
        let fill_amount = my_orders.fill_amount(i);
        
        if account.stock == 0 {
            entry_price = fill_price;
            if fill_side == 0 {
                entry_side = 0;
            } else {
                entry_side = 1;
            }
        } else {
            let profit = 0;
            if entry_side == 0 && fill_side == 1 {
                profit = (fill_price - entry_price) * fill_amount;
            } else if entry_side == 1 && fill_side == 0 {
                profit = (entry_price - fill_price) * fill_amount;
            }
            
            if profit <= 0 {
                if multiplier < MAX_MULTIPLIER {
                    multiplier *= 2;
                }
            } else {
                multiplier = 1;
            }
        }
        i += 1;
    }
    
    let current_lot = BASE_LOT * multiplier;
    
    let pending_exists = my_orders.pending_count() > 0;
    
    if !pending_exists && account.stock == 0 && current_price != last_price {
        if current_price < last_price {
            let buy_price = current_price - TICK_SIZE;
            if buy_price > 0 {
                orders.submit_limit_buy(buy_price, current_lot);
            }
        } else if current_price > last_price {
            let sell_price = current_price + TICK_SIZE;
            orders.submit_limit_sell(sell_price, current_lot);
        }
    }
    
    if !pending_exists && account.stock != 0 {
        if account.stock > 0 {
            let sell_price = current_price + TICK_SIZE;
            orders.submit_limit_sell(sell_price, account.stock);
        } else {
            let buy_price = current_price - TICK_SIZE;
            if buy_price > 0 {
                orders.submit_limit_buy(buy_price, -account.stock);
            }
        }
    }
    
    last_price = current_price;
}