let price_history = [];
let delayed_price = 0;
let spread_micros = 5000;
let order_amount = 100;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() == 5 {
        delayed_price = price_history[0];
    } else {
        return;
    }
    
    let current_tick = market.tick;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    let has_buy = false;
    let has_sell = false;
    let pending_cnt2 = my_orders.pending_count();
    let j = 0;
    while j < pending_cnt2 {
        let side = my_orders.pending_side(j);
        if side == 0 {
            has_buy = true;
        } else if side == 1 {
            has_sell = true;
        }
        j += 1;
    }
    
    let buy_price = delayed_price - spread_micros;
    let sell_price = delayed_price + spread_micros;
    
    if !has_buy && buy_price > 0 {
        orders.submit_limit_buy(buy_price, order_amount);
    }
    
    if !has_sell {
        orders.submit_limit_sell(sell_price, order_amount);
    }
}