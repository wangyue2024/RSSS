let initialized = false;
let trade_amount = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        trade_amount = 100;
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
    let ma20 = market.ma_20;
    let price = market.price;
    
    if atr == 0 || ma20 == 0 { return; }
    
    let threshold = (atr * 150) / 100;
    let diff = price - ma20;
    let abs_diff = abs_val(diff);
    
    if abs_diff > threshold {
        if diff > 0 {
            let ask_price = if market.ask_price_0 != 0 { market.ask_price_0 } else { price };
            orders.submit_limit_sell(ask_price, trade_amount);
        } else {
            let bid_price = if market.bid_price_0 != 0 { market.bid_price_0 } else { price };
            orders.submit_limit_buy(bid_price + 1, trade_amount);
        }
    }
}