let evaluation_tick = -1;
let pending_buy_id = 0;
let buy_placed_tick = 0;
let pending_sell_id = 0;
let sell_placed_tick = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if current_tick % 50 != 0 { return; }
    
    let price = market.price;
    let high_20 = market.high_20;
    let avg_cost = account.avg_cost;
    let stock = account.stock;
    let cash = account.cash;
    
    if stock == 0 && price > high_20 && cash > 0 {
        let buy_amount = cash / price;
        if buy_amount > 0 {
            let buy_order_price = price + micros(0, 1);
            let order_id = orders.submit_limit_buy(buy_order_price, buy_amount);
            if order_id > 0 {
                pending_buy_id = order_id;
                buy_placed_tick = current_tick;
            }
        }
    }
    
    if stock > 0 && price > avg_cost {
        let sell_order_price = price - micros(0, 1);
        let order_id = orders.submit_limit_sell(sell_order_price, stock);
        if order_id > 0 {
            pending_sell_id = order_id;
            sell_placed_tick = current_tick;
        }
    }
}