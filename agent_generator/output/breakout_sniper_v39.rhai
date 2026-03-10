let initialized = false;
let price_history = [];
let pending_buy_id = 0;
let pending_buy_placed = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    if price_history.len() < 5 {
        return;
    }
    
    let delayed_price = price_history[0];
    
    let stop_offset = 50_000;
    
    if my_orders.pending_count() > 0 {
        let count = my_orders.pending_count();
        let i = 0;
        while i < count {
            let oid = my_orders.pending_id(i);
            let placed = my_orders.pending_placed_tick(i);
            if market.tick - placed > 3 {
                orders.submit_cancel(oid);
            }
            i += 1;
        }
    }
    
    if account.stock > 0 {
        if market.price <= account.avg_cost - stop_offset {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    if my_orders.pending_count() > 0 {
        return;
    }
    
    if delayed_price > market.high_20 {
        let amount = 100;
        let buy_price = market.ask_price_0;
        orders.submit_limit_buy(buy_price, amount);
    }
}