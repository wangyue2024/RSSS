let ma_5_prev = 0;
let ma_20_prev = 0;
let initialized = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        ma_5_prev = market.ma_5;
        ma_20_prev = market.ma_20;
        initialized = true;
        return;
    }
    
    let ma_5_curr = market.ma_5;
    let ma_20_curr = market.ma_20;
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.stock == 0 && ma_5_prev <= ma_20_prev && ma_5_curr > ma_20_curr {
        let amount = 100;
        let target_price = market.ask_price_0 + 1;
        if target_price > 0 {
            orders.submit_limit_buy(target_price, amount);
        }
    }
    
    if account.stock > 0 && ma_5_prev >= ma_20_prev && ma_5_curr < ma_20_curr {
        orders.submit_market_sell(account.stock);
    }
    
    ma_5_prev = ma_5_curr;
    ma_20_prev = ma_20_curr;
}