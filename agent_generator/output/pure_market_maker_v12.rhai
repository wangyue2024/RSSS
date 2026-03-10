let SPREAD = 2000;
let ORDER_AMOUNT = 1000;
let MAX_ORDER_AGE = 3;

fn on_tick() {
    if !market.trading_enabled {
        return;
    }
    
    let current_price = market.price;
    let buy_price = current_price - SPREAD;
    let sell_price = current_price + SPREAD;
    
    if buy_price < 1 {
        buy_price = 1;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let order_age = market.tick - my_orders.pending_placed_tick(i);
        if order_age > MAX_ORDER_AGE {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let has_buy_order = false;
    let has_sell_order = false;
    
    let j = 0;
    let new_pending_count = my_orders.pending_count();
    while j < new_pending_count {
        let side = my_orders.pending_side(j);
        if side == 0 {
            has_buy_order = true;
        } else if side == 1 {
            has_sell_order = true;
        }
        j += 1;
    }
    
    if !has_buy_order && buy_price > 0 {
        orders.submit_limit_buy(buy_price, ORDER_AMOUNT);
    }
    
    if !has_sell_order {
        orders.submit_limit_sell(sell_price, ORDER_AMOUNT);
    }
}