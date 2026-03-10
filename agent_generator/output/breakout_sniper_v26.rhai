let initialized = false;
let stop_loss_offset = 0;
let price_history = [];
let last_fomo_check = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        stop_loss_offset = micros(0, 500);
        last_fomo_check = market.tick;
    }
    
    if !market.trading_enabled { return; }
    
    let current_price = market.price;
    let current_tick = market.tick;
    
    price_history.push(current_price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    let fomo_triggered = false;
    if price_history.len() == 5 {
        let old_price = price_history[0];
        if old_price > 0 && current_price > 0 {
            let price_change = (current_price - old_price) * 10000 / old_price;
            if price_change > 200 {
                fomo_triggered = true;
            }
        }
    }
    
    if fomo_triggered && account.cash > micros(1, 0) {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        
        let buy_amount = account.cash * 80 / 100 / current_price;
        if buy_amount > 0 {
            orders.submit_market_buy(buy_amount);
        }
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick >= 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if account.stock > 0 && current_price < account.avg_cost - stop_loss_offset {
        orders.submit_market_sell(account.stock);
    }
    
    if current_price > market.high_20 && market.high_20 > 0 {
        let buy_amount = account.cash * 60 / 100 / current_price;
        if buy_amount > 0 {
            let bid_price = market.ask_price_0;
            if bid_price == 0 {
                bid_price = current_price;
            }
            orders.submit_limit_buy(bid_price, buy_amount);
        }
    }
}