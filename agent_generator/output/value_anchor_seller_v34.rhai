let initialized = false;
let fair_value = 0;
let panic_threshold = 0;
let price_buffer = [];

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(98_000_000, 102_000_000);
        panic_threshold = -rng.rand_int(500_000, 2_000_000);
    }
    
    if !market.trading_enabled { return; }
    
    price_buffer.push(market.price);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if price_buffer.len() >= 5 {
        let delayed_price = price_buffer[0];
        
        if delayed_price > fair_value && account.stock > 0 {
            let sell_amount = 0;
            let round_price = 0;
            
            if delayed_price > fair_value * 110 / 100 {
                sell_amount = account.stock * 30 / 100;
                round_price = (delayed_price / 1_000_000) * 1_000_000;
                if sell_amount > 0 {
                    orders.submit_limit_sell(round_price, sell_amount);
                }
            } else if delayed_price > fair_value * 105 / 100 {
                sell_amount = account.stock * 10 / 100;
                round_price = (delayed_price / 1_000_000) * 1_000_000;
                if sell_amount > 0 {
                    orders.submit_limit_sell(round_price, sell_amount);
                }
            }
        }
    }
}