let initialized = false;
let active = true;
let price_history = [];
let rsi_history = [];
let tick_buffer = 0;
let decision_price = 0;
let decision_rsi = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        active = true;
    }
    
    if !market.trading_enabled { return; }
    
    let total_ticks = market.total_ticks;
    let current_tick = market.tick;
    
    if current_tick >= total_ticks / 5 {
        active = false;
        let pending = my_orders.pending_count();
        let i = 0;
        while i < pending {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
        return;
    }
    
    if !active { return; }
    
    price_history.push(market.price);
    rsi_history.push(market.rsi_14);
    
    if price_history.len() > 5 {
        price_history.remove(0);
        rsi_history.remove(0);
    }
    
    if price_history.len() == 5 {
        decision_price = price_history[0];
        decision_rsi = rsi_history[0];
        tick_buffer = current_tick;
    }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_history.len() < 5 { return; }
    
    if decision_rsi < 3000 {
        let amount = rng.rand_int(20, 100);
        let limit_price = market.bid_price_0;
        if limit_price == 0 {
            limit_price = market.price - 10000;
        }
        if limit_price > 0 && account.cash >= amount * limit_price {
            orders.submit_limit_buy(limit_price, amount);
        }
    } else if decision_rsi > 7000 && account.stock > 0 {
        let amount = rng.rand_int(20, 100);
        if amount > account.stock {
            amount = account.stock;
        }
        let limit_price = market.ask_price_0;
        if limit_price == 0 {
            limit_price = market.price + 10000;
        }
        if limit_price > 0 {
            orders.submit_limit_sell(limit_price, amount);
        }
    }
}