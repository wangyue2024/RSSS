let initialized = false;
let panic_threshold = 0;
let trade_amount = 100;

fn on_tick() {
    if !initialized {
        panic_threshold = -rng.rand_int(1000, 5000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if account.unrealized_pnl <= panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let ma = market.ma_20;
    let std = market.std_dev;
    
    if ma > 0 && std > 0 && market.price > 0 {
        let lower_band = ma - 2 * std;
        let upper_band = ma + 2 * std;
        
        let buy_price = lower_band;
        let sell_price = upper_band;
        
        if buy_price > 0 && account.cash >= buy_price * trade_amount {
            orders.submit_limit_buy(buy_price, trade_amount);
        }
        
        if sell_price > 0 && account.stock >= trade_amount {
            orders.submit_limit_sell(sell_price, trade_amount);
        }
    }
}