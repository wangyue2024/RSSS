let recent_prices = [];
let initialized = false;
let position_size = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        if market.trading_enabled {
            position_size = rng.rand_int(80, 120);
        }
    }
    
    if !market.trading_enabled { return; }
    
    recent_prices.push(market.price);
    if recent_prices.len() > 5 {
        recent_prices.remove(0);
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if recent_prices.len() < 5 {
        return;
    }
    
    let delayed_price = recent_prices[0];
    let atr = market.atr_14;
    let ma20 = market.ma_20;
    
    if atr == 0 || ma20 == 0 {
        return;
    }
    
    let threshold = (atr * 15) / 10;
    let deviation = delayed_price - ma20;
    
    if deviation > threshold && account.stock >= position_size {
        let target_price = ma20 + (threshold * 80) / 100;
        orders.submit_limit_sell(target_price, position_size);
    } else if deviation < -threshold {
        let buy_amount = position_size;
        let max_buy = account.cash / market.price;
        if max_buy < buy_amount {
            buy_amount = max_buy;
        }
        if buy_amount > 0 {
            let target_price = ma20 - (threshold * 80) / 100;
            orders.submit_limit_buy(target_price, buy_amount);
        }
    }
}