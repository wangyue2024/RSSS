let initialized = false;
let has_entered = false;
let entry_tick = 0;
let tp_order_id = 0;
let last_prices = [];
let fomo_triggered = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        last_prices.push(market.price);
    }
    
    if !market.trading_enabled { return; }
    
    last_prices.push(market.price);
    if last_prices.len() > 5 {
        last_prices.remove(0);
    }
    
    let price_jump = false;
    if last_prices.len() >= 2 {
        let prev_price = last_prices[last_prices.len() - 2];
        let jump_percent = (market.price - prev_price) * 10000 / prev_price;
        if jump_percent > 200 {
            price_jump = true;
        }
    }
    
    if price_jump && !fomo_triggered {
        fomo_triggered = true;
        let pending_count = my_orders.pending_count();
        let i = 0;
        while i < pending_count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        orders.submit_market_buy(100);
        return;
    }
    
    if fomo_triggered {
        return;
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick >= 3 {
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if !has_entered {
        if rng.rand_bool(5) {
            orders.submit_market_buy(100);
            has_entered = true;
            entry_tick = market.tick;
        }
        return;
    }
    
    if account.stock == 0 {
        has_entered = false;
        tp_order_id = 0;
        return;
    }
    
    let tp_active = false;
    let pending_count2 = my_orders.pending_count();
    let j = 0;
    while j < pending_count2 {
        let oid = my_orders.pending_id(j);
        if oid == tp_order_id {
            tp_active = true;
            break;
        }
        j += 1;
    }
    
    if !tp_active && account.avg_cost > 0 {
        let take_profit_price = account.avg_cost * 105 / 100;
        if take_profit_price > market.price {
            tp_order_id = orders.submit_limit_sell(take_profit_price, account.stock);
        }
    }
    
    if account.avg_cost > 0 {
        let stop_loss_price = account.avg_cost * 98 / 100;
        if market.price < stop_loss_price {
            orders.submit_market_sell(account.stock);
            tp_order_id = 0;
        }
    }
}