let price_history = [];
let initialized = false;

fn round_to_nearest_dollar(price_micros) {
    ((price_micros + 500_000) / 1_000_000) * 1_000_000
}

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled {
        return;
    }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
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
        let current_price = market.price;
        
        let price_change_pct = (current_price - delayed_price) * 10000 / delayed_price;
        if price_change_pct > 200 {
            orders.submit_market_buy(100);
            return;
        }
        
        let vwap = market.vwap;
        let threshold = 50;
        
        if account.stock == 0 && delayed_price * 10000 < vwap * (10000 - threshold) {
            let buy_price = round_to_nearest_dollar(delayed_price);
            if buy_price > 0 {
                orders.submit_limit_buy(buy_price, 100);
            }
        } else if account.stock > 0 && delayed_price >= vwap {
            let sell_price = round_to_nearest_dollar(vwap);
            if sell_price > 0 {
                orders.submit_limit_sell(sell_price, account.stock);
            }
        }
    }
}