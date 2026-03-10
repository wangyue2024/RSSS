let initialized = false;
let lot_size = 0;
let prev_ma5 = 0;
let prev_ma20 = 0;

fn on_tick() {
    if !initialized {
        let capital = account.total_equity;
        let five_percent = capital * 5 / 100;
        if market.price > 0 {
            let max_shares = five_percent / market.price;
            if max_shares > 0 {
                lot_size = rng.rand_int(1, max_shares);
            } else {
                lot_size = 1;
            }
        } else {
            lot_size = 1;
        }
        prev_ma5 = market.ma_5;
        prev_ma20 = market.ma_20;
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.std_dev * 100 > market.price * 2 {
        return;
    }
    
    let ma5 = market.ma_5;
    let ma20 = market.ma_20;
    
    let buy_signal = prev_ma5 <= prev_ma20 && ma5 > ma20;
    let sell_signal = prev_ma5 >= prev_ma20 && ma5 < ma20;
    
    if buy_signal && account.cash > 0 {
        orders.submit_market_buy(lot_size);
    } else if sell_signal && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }
    
    prev_ma5 = ma5;
    prev_ma20 = ma20;
}