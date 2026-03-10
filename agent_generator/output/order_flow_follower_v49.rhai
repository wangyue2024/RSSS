let initialized = false;
let buy_vol_history = [];
let sell_vol_history = [];
let price_history = [];
let lot_size = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        lot_size = account.cash * rng.rand_int(40, 50) / 100;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    buy_vol_history.push(market.buy_volume);
    sell_vol_history.push(market.sell_volume);
    price_history.push(market.price);
    
    if buy_vol_history.len() > 5 {
        buy_vol_history.remove(0);
        sell_vol_history.remove(0);
        price_history.remove(0);
    }
    
    if buy_vol_history.len() == 5 {
        let old_buy = buy_vol_history[0];
        let old_sell = sell_vol_history[0];
        
        if old_buy > 3 * old_sell {
            let shares = lot_size / market.price;
            if shares > 0 && account.cash >= market.price {
                orders.submit_market_buy(shares);
            }
        }
    }
}