let initialized = false;
let fomo_triggered = false;
let base_order_size = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_order_size = rng.rand_int(80, 120);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.history_len() > 5 {
        let current_price = market.price;
        let price_5_ago = market.history_price(5);
        let change = (current_price - price_5_ago) * 100 / price_5_ago;
        if change > 20000 && !fomo_triggered {
            fomo_triggered = true;
            let buy_shares = account.cash / (current_price * 2);
            if buy_shares > 0 {
                orders.submit_market_buy(buy_shares);
            }
            return;
        }
    }
    
    fomo_triggered = false;
    
    let low_20 = market.low_20;
    let high_20 = market.high_20;
    let spread = high_20 - low_20;
    
    let spread_narrow = spread < (market.price * 10000 / 1000000);
    
    let size_mult = if spread_narrow { 2 } else { 1 };
    let order_shares = base_order_size * size_mult;
    
    if order_shares > 0 {
        let buy_target = low_20 + spread * 10 / 100;
        let rounded_buy = ((buy_target + 500_000) / 1_000_000) * 1_000_000;
        
        if rounded_buy < market.price && account.cash >= rounded_buy * order_shares {
            orders.submit_limit_buy(rounded_buy, order_shares);
        }
        
        if market.price > account.avg_cost && account.stock >= order_shares {
            let sell_target = high_20 - spread * 10 / 100;
            let rounded_sell = ((sell_target + 500_000) / 1_000_000) * 1_000_000;
            
            if rounded_sell > market.price {
                orders.submit_limit_sell(rounded_sell, order_shares);
            }
        }
    }
}