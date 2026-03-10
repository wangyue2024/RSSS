let initialized = false;
let trade_amount = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        trade_amount = rng.rand_int(80, 120);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let atr = market.atr_14;
    let ma20 = market.ma_20;
    let price = market.price;
    
    if atr == 0 || ma20 == 0 { return; }
    
    let deviation = price - ma20;
    let abs_deviation = abs_val(deviation);
    let threshold = (3 * atr) / 2;
    
    if deviation > threshold && account.stock >= trade_amount {
        let sell_price = ma20 - 1;
        if sell_price > 0 {
            orders.submit_limit_sell(sell_price, trade_amount);
        }
    } else if deviation < -threshold && account.cash >= ma20 * trade_amount {
        let buy_price = ma20 + 1;
        orders.submit_limit_buy(buy_price, trade_amount);
    }
}