let initialized = false;
let last_decision_tick = -50;
let prev_ma5_above_ma20 = false;
let price_history = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() == 5 {
        let price_5_ticks_ago = price_history[0];
        let price_change_pct = (market.price - price_5_ticks_ago) * 100 / price_5_ticks_ago;
        if price_change_pct > 2 {
            fomo_triggered = true;
            let pending_cnt = my_orders.pending_count();
            let i = 0;
            while i < pending_cnt {
                let oid = my_orders.pending_id(i);
                orders.submit_cancel(oid);
                i += 1;
            }
            if account.cash > 0 {
                let buy_amount = account.cash / market.price;
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                }
            }
        }
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if current_tick - last_decision_tick >= 50 && !fomo_triggered {
        last_decision_tick = current_tick;
        
        let ma5 = market.ma_5;
        let ma20 = market.ma_20;
        let current_ma5_above_ma20 = ma5 > ma20;
        
        if initialized && current_ma5_above_ma20 && !prev_ma5_above_ma20 {
            let pending_cnt2 = my_orders.pending_count();
            let j = 0;
            while j < pending_cnt2 {
                let oid = my_orders.pending_id(j);
                orders.submit_cancel(oid);
                j += 1;
            }
            if account.cash > 0 {
                let buy_amount = account.cash / market.price;
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                }
            }
        } else if initialized && !current_ma5_above_ma20 && prev_ma5_above_ma20 {
            let pending_cnt2 = my_orders.pending_count();
            let j = 0;
            while j < pending_cnt2 {
                let oid = my_orders.pending_id(j);
                orders.submit_cancel(oid);
                j += 1;
            }
            if account.stock > 0 {
                orders.submit_market_sell(account.stock);
            }
        }
        
        prev_ma5_above_ma20 = current_ma5_above_ma20;
        fomo_triggered = false;
    }
}