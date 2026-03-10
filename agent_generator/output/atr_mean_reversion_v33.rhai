let initialized = false;
let my_order_amount = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        my_order_amount = rng.rand_int(80, 120) * 100;
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let atr = market.atr_14;
    let ma_20 = market.ma_20;
    let price = market.price;
    let deviation = price - ma_20;
    let threshold = (atr * 3) / 2;
    
    let rounded_price = ((price + 500_000) / 1_000_000) * 1_000_000;
    
    if deviation > threshold && account.stock > 0 {
        orders.submit_limit_sell(rounded_price, my_order_amount);
    } else if deviation < -threshold && account.cash > price * my_order_amount {
        orders.submit_limit_buy(rounded_price, my_order_amount);
    }
}