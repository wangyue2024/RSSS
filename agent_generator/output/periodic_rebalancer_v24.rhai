let initialized = false;
let price_history = [];
let last_fomo_check = -1;

fn on_tick() {
    if !initialized {
        initialized = true;
        price_history = [];
        last_fomo_check = -1;
    }
    
    if !market.trading_enabled {
        return;
    }

    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }

    let current_tick = market.tick;

    let fomo_triggered = false;
    if price_history.len() == 5 {
        let old_price = price_history[0];
        let current_price = price_history[4];
        let change_pct = (current_price - old_price) * 100 / old_price;
        if change_pct > 2 {
            fomo_triggered = true;
        }
    }

    if fomo_triggered {
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        let buy_amount = account.cash / market.price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        return;
    }

    if current_tick % 50 != 0 {
        return;
    }

    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }

    let stock_value = account.stock * market.price;
    let total_equity = account.total_equity;
    
    if total_equity <= 0 {
        return;
    }

    let stock_pct = stock_value * 100 / total_equity;
    
    if stock_pct > 55 {
        let target_value = total_equity * 50 / 100;
        let excess_value = stock_value - target_value;
        let sell_amount = excess_value / market.price;
        
        if sell_amount > 0 {
            let limit_price = market.price * 101 / 100;
            orders.submit_limit_sell(limit_price, sell_amount);
        }
    } else if stock_pct < 45 {
        let target_value = total_equity * 50 / 100;
        let deficit_value = target_value - stock_value;
        let buy_amount = deficit_value / market.price;
        
        if buy_amount > 0 {
            let limit_price = market.price * 99 / 100;
            orders.submit_limit_buy(limit_price, buy_amount);
        }
    }
}