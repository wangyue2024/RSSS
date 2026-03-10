let initialized = false;
let lot_size = 0;
let price_history = [];
let buy_vol_history = [];
let sell_vol_history = [];
let delay_ticks = 5;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        let max_lot_value = account.total_equity * 5 / 100;
        let price = market.price;
        if price > 0 {
            lot_size = max_lot_value / price;
        } else {
            lot_size = 0;
        }
        if lot_size < 1 {
            lot_size = 1;
        }
        initialized = true;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_history.push(market.price);
    buy_vol_history.push(market.buy_volume);
    sell_vol_history.push(market.sell_volume);
    
    if price_history.len() > 10 {
        price_history.remove(0);
        buy_vol_history.remove(0);
        sell_vol_history.remove(0);
    }
    
    if price_history.len() > delay_ticks {
        let old_idx = price_history.len() - delay_ticks - 1;
        let old_buy_vol = buy_vol_history[old_idx];
        let old_sell_vol = sell_vol_history[old_idx];
        
        let std_dev_threshold = market.price * 2 / 100;
        if market.std_dev < std_dev_threshold {
            if old_buy_vol > old_sell_vol * 3 && lot_size > 0 {
                orders.submit_market_buy(lot_size);
            }
        }
    }
}