let ma5_history = [];
let ma20_history = [];
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    ma5_history.push(market.ma_5);
    ma20_history.push(market.ma_20);
    
    if ma5_history.len() > 5 {
        ma5_history.remove(0);
        ma20_history.remove(0);
    }
    
    if ma5_history.len() < 5 { return; }
    
    let ma5_old = ma5_history[0];
    let ma20_old = ma20_history[0];
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let round_price_factor = 1_000_000;
    let half = 500_000;
    let remainder = market.price % round_price_factor;
    let round_price = market.price - remainder;
    if remainder >= half {
        round_price = round_price + round_price_factor;
    }
    
    if (ma5_old > ma20_old) && (account.stock == 0) {
        let max_shares = account.cash / round_price;
        if max_shares > 0 {
            orders.submit_limit_buy(round_price, max_shares);
        }
    }
    
    if (ma5_old < ma20_old) && (account.stock > 0) {
        orders.submit_limit_sell(round_price, account.stock);
    }
}