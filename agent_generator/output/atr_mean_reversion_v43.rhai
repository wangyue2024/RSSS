let price_history = [];
let ma_history = [];
let atr_history = [];

let initialized = false;
let base_trade_amount = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_trade_amount = rng.rand_int(50, 150);
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    ma_history.push(market.ma_20);
    atr_history.push(market.atr_14);
    
    if price_history.len() > 5 {
        price_history.remove(0);
        ma_history.remove(0);
        atr_history.remove(0);
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_history.len() == 5 {
        let delayed_price = price_history[0];
        let delayed_ma = ma_history[0];
        let delayed_atr = atr_history[0];
        
        let deviation = delayed_price - delayed_ma;
        let threshold = (delayed_atr * 3) / 2;
        
        let target_price = delayed_price;
        
        if deviation > threshold && account.stock > 0 {
            target_price = delayed_ma + threshold;
        } else if deviation < -threshold && account.cash > 0 {
            target_price = delayed_ma - threshold;
        } else {
            return;
        }
        
        let rounded_price = ((target_price + 500_000) / 1_000_000) * 1_000_000;
        let amount = base_trade_amount;
        
        if deviation > threshold && account.stock >= amount {
            orders.submit_limit_sell(rounded_price, amount);
        } else if deviation < -threshold && account.cash >= rounded_price * amount / 1_000_000 {
            orders.submit_limit_buy(rounded_price, amount);
        }
    }
}