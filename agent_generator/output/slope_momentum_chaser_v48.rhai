let initialized = false;
let fomo_triggered = false;
let lookback_period = 20;
let short_window = 5;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick * 100 / market.total_ticks > 20 {
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            orders.submit_cancel(my_orders.pending_id(i));
            i += 1;
        }
        return;
    }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    let current_price = market.price;
    
    if market.history_len() >= short_window {
        let price_short_ago = market.history_price(short_window - 1);
        if price_short_ago > 0 {
            let price_change_pct = (current_price - price_short_ago) * 10000 / price_short_ago;
            if price_change_pct > 200 {
                fomo_triggered = true;
                let buy_amount = account.cash * 50 / 100 / current_price;
                if buy_amount > 0 && current_price > 0 {
                    orders.submit_market_buy(buy_amount);
                }
                return;
            }
        }
    }
    
    fomo_triggered = false;
    
    if market.history_len() >= lookback_period {
        let price_array = [];
        let j = 0;
        while j < lookback_period {
            price_array.push(market.history_price(j));
            j += 1;
        }
        
        let slope = arr_slope(price_array);
        
        let slope_array_short = [];
        let k = 0;
        while k < 10 && k < market.history_len() {
            slope_array_short.push(market.history_price(k));
            k += 1;
        }
        
        let short_slope = arr_slope(slope_array_short);
        
        if slope > 0 && short_slope > slope && market.bid_price_0 > 0 {
            let bid_price = market.bid_price_0 + 1;
            let buy_amount = account.cash * 20 / 100 / bid_price;
            if buy_amount > 0 {
                orders.submit_limit_buy(bid_price, buy_amount);
            }
        }
        
        if short_slope < 0 && account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
    }
}