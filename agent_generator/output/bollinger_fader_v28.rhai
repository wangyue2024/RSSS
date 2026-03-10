let initialized = false;
let trade_amount = 100;
let buy_order_id = -1;
let sell_order_id = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let ma = market.ma_20;
    let std = market.std_dev;
    
    if ma == 0 || std == 0 { return; }
    
    let lower_band = ma - 2 * std;
    let upper_band = ma + 2 * std;
    
    let i = 0;
    let pending_count = my_orders.pending_count();
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if lower_band > 0 && account.cash >= lower_band * trade_amount {
        buy_order_id = orders.submit_limit_buy(lower_band, trade_amount);
    }
    
    if account.stock >= trade_amount && upper_band > account.avg_cost {
        sell_order_id = orders.submit_limit_sell(upper_band, trade_amount);
    }
}