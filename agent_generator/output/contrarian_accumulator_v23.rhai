let initialized = false;
let base_order_size = 0;
let last_action_tick = -1000;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_order_size = rng.rand_int(20, 100);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if current_tick - last_action_tick < 100 { return; }
    
    let rsi = market.rsi_14;
    let price = market.price;
    let avg_cost = account.avg_cost;
    
    if rsi < 3000 && account.cash > 100_000_000 {
        let total_buy_amount = base_order_size;
        if total_buy_amount <= 0 { return; }
        
        let buy_price_raw = price * 98 / 100;
        let buy_price_rounded = ((buy_price_raw + 500_000) / 1_000_000) * 1_000_000;
        if buy_price_rounded <= 0 { return; }
        
        let amount_per_order = total_buy_amount;
        if amount_per_order > 0 {
            orders.submit_limit_buy(buy_price_rounded, amount_per_order);
            last_action_tick = current_tick;
        }
    }
    
    if rsi > 7000 && account.stock > 0 && price > avg_cost {
        let total_sell_amount = base_order_size;
        if total_sell_amount > account.stock {
            total_sell_amount = account.stock;
        }
        if total_sell_amount <= 0 { return; }
        
        let sell_price_raw = price * 102 / 100;
        let sell_price_rounded = ((sell_price_raw + 500_000) / 1_000_000) * 1_000_000;
        if sell_price_rounded <= avg_cost { return; }
        
        let amount_per_order = total_sell_amount;
        if amount_per_order > 0 {
            orders.submit_limit_sell(sell_price_rounded, amount_per_order);
            last_action_tick = current_tick;
        }
    }
}