let lookback_ticks = 10;
let last_check_tick = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_tick = market.tick;
    if current_tick >= lookback_ticks {
        let past_tick = current_tick - lookback_ticks;
        let past_price = market.history_price(past_tick);
        let current_price = market.price;
        
        if past_price > 0 {
            let price_change_percent = (current_price - past_price) * 10000 / past_price;
            
            if price_change_percent > 200 {
                let cash_to_use = account.cash * 20 / 100;
                let amount = cash_to_use / current_price;
                if amount > 0 {
                    orders.submit_market_buy(amount);
                }
                return;
            }
        }
    }
    
    if market.sell_volume > 0 {
        let ratio = market.buy_volume * 100 / market.sell_volume;
        
        if ratio >= 300 {
            let cash_to_use = account.cash * 15 / 100;
            let amount = cash_to_use / market.price;
            if amount > 0 {
                orders.submit_market_buy(amount);
            }
        }
    }
}