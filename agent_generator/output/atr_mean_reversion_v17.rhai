let price_history = [];
let atr_history = [];
let ma20_history = [];
let initialized = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        price_history.push(market.price);
        atr_history.push(market.atr_14);
        ma20_history.push(market.ma_20);
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_history.push(market.price);
    atr_history.push(market.atr_14);
    ma20_history.push(market.ma_20);
    
    if price_history.len() > 5 {
        price_history.remove(0);
        atr_history.remove(0);
        ma20_history.remove(0);
    }
    
    if price_history.len() == 5 {
        let old_price = price_history[0];
        let old_atr = atr_history[0];
        let old_ma20 = ma20_history[0];
        
        let threshold = old_atr * 3 / 2;
        
        if old_price > old_ma20 + threshold {
            let sell_price = old_ma20 - 1;
            let amount = 100;
            orders.submit_limit_sell(sell_price, amount);
        }
        
        if old_price < old_ma20 - threshold {
            let buy_price = old_ma20 + 1;
            let amount = 100;
            orders.submit_limit_buy(buy_price, amount);
        }
    }
}