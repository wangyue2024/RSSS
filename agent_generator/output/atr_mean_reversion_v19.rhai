let initialized = false;
let order_tick_tracker = [];

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if my_orders.pending_count() > 0 { return; }
    
    let price = market.price;
    let ma20 = market.ma_20;
    let atr = market.atr_14;
    
    if price == 0 || ma20 == 0 || atr == 0 { return; }
    
    let deviation = price - ma20;
    let abs_deviation = abs_val(deviation);
    let threshold = atr * 150 / 100;
    
    let max_position = 1000;
    let base_order_size = 100;
    let cash = account.cash;
    let stock = account.stock;
    
    if deviation > threshold && stock >= base_order_size {
        let sell_price = price + atr * 10 / 100;
        orders.submit_limit_sell(sell_price, base_order_size);
    } else if deviation < -threshold && cash > price * base_order_size {
        let buy_price = price - atr * 10 / 100;
        orders.submit_limit_buy(buy_price, base_order_size);
    }
}