let initialized = false;
let panic_threshold = 0;
let target_position = 50_000;
let slice_size = 500;
let trade_frequency = 10;
let ticks_since_last_trade = 0;
let price_history = [];
let pnl_history = [];

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        panic_threshold = -rng.rand_int(10_000, 50_000);
        initialized = true;
    }
    
    price_history.push(market.price);
    pnl_history.push(account.unrealized_pnl);
    
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    if pnl_history.len() > 5 {
        pnl_history.remove(0);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_history.len() >= 5 {
        let old_pnl = pnl_history[0];
        
        if old_pnl < panic_threshold && account.stock > 0 {
            orders.submit_market_sell(account.stock);
            return;
        }
        
        ticks_since_last_trade += 1;
        if ticks_since_last_trade >= trade_frequency {
            ticks_since_last_trade = 0;
            
            let current_position = account.stock;
            if current_position < target_position {
                let needed = target_position - current_position;
                let buy_amount = if needed < slice_size { needed } else { slice_size };
                if buy_amount > 0 {
                    orders.submit_market_buy(buy_amount);
                }
            }
        }
    }
}