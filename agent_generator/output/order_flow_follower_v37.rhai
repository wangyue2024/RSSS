let initialized = false;
let trade_fraction = 0;
let price_history = [];
let buy_vol_history = [];
let sell_vol_history = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        trade_fraction = rng.rand_int(30, 50);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_history.push(market.price);
    buy_vol_history.push(market.buy_volume);
    sell_vol_history.push(market.sell_volume);
    
    if price_history.len() > 5 {
        price_history.remove(0);
        buy_vol_history.remove(0);
        sell_vol_history.remove(0);
    }
    
    if price_history.len() == 5 {
        let old_buy_vol = buy_vol_history[0];
        let old_sell_vol = sell_vol_history[0];
        let old_price = price_history[0];
        
        if old_buy_vol > 3 * old_sell_vol {
            let cash_to_use = account.cash * trade_fraction / 100;
            if cash_to_use > 0 && old_price > 0 {
                let shares_to_buy = cash_to_use / old_price;
                if shares_to_buy > 0 {
                    orders.submit_limit_buy(old_price, shares_to_buy);
                }
            }
        }
    }
}