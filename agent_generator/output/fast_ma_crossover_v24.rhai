let initialized = false;
let prev_ma_5 = 0;
let prev_ma_20 = 0;
let price_history = [];
let last_evaluation_tick = 0;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    let i = 0;
    let pending_cnt = my_orders.pending_count();
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if !initialized {
        initialized = true;
        prev_ma_5 = market.ma_5;
        prev_ma_20 = market.ma_20;
        last_evaluation_tick = market.tick;
    }
    
    if price_history.len() >= 10 {
        price_history.remove(0);
    }
    price_history.push(market.price);
    
    let fomo_triggered = false;
    if price_history.len() >= 2 {
        let old_price = price_history[0];
        let change_bps = (market.price - old_price) * 10000 / old_price;
        if change_bps > 200 && account.stock == 0 {
            let buy_amount = account.cash / market.price;
            if buy_amount > 0 {
                orders.submit_market_buy(buy_amount);
                fomo_triggered = true;
                return;
            }
        }
    }
    
    if market.tick % 50 != 0 {
        return;
    }
    
    let ma_5_crossed_above = prev_ma_5 <= prev_ma_20 && market.ma_5 > market.ma_20;
    let ma_5_crossed_below = prev_ma_5 >= prev_ma_20 && market.ma_5 < market.ma_20;
    
    if ma_5_crossed_above && account.stock == 0 {
        let buy_amount = account.cash / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
    } else if ma_5_crossed_below && account.stock > 0 {
        orders.submit_market_sell(account.stock);
    }
    
    prev_ma_5 = market.ma_5;
    prev_ma_20 = market.ma_20;
}