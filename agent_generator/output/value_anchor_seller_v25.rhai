let initialized = false;
let fair_value = 0;
let price_buffer = [];

fn on_tick() {
    if !initialized {
        fair_value = 100_000_000 + rng.rand_int(-1_000_000, 1_000_000);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    price_buffer.push(market.price);
    if price_buffer.len() > 10 {
        price_buffer.remove(0);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_buffer.len() >= 6 {
        let old_price = price_buffer[price_buffer.len() - 6];
        let threshold_105 = fair_value * 105 / 100;
        let threshold_110 = fair_value * 110 / 100;
        
        if old_price > threshold_110 {
            let sell_amount = rng.rand_int(50, 100);
            if sell_amount > account.stock {
                sell_amount = account.stock;
            }
            if sell_amount > 0 {
                orders.submit_limit_sell(market.ask_price_0, sell_amount);
            }
        } else if old_price > threshold_105 {
            let sell_amount = rng.rand_int(10, 30);
            if sell_amount > account.stock {
                sell_amount = account.stock;
            }
            if sell_amount > 0 {
                orders.submit_limit_sell(market.ask_price_0, sell_amount);
            }
        }
    }
}