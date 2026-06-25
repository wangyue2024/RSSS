let initialized = false;
let panic_threshold = 0;
let tick_counter = 0;
let my_spread = 10000;

fn on_tick() {
    if !initialized {
        initialized = true;
        panic_threshold = -rng.rand_int(15000, 50000);
        my_spread = rng.rand_int(8000, 15000);
    }
    
    if !market.trading_enabled { return; }
    
    if account.unrealized_pnl < panic_threshold {
        if account.stock > 0 {
            orders.submit_market_sell(account.stock);
        }
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    tick_counter += 1;
    if tick_counter >= 10 {
        tick_counter = 0;
        
        let total_eq = account.total_equity;
        if total_eq <= 0 { return; }
        
        let stock_val = account.stock * market.price;
        let stock_pct = stock_val * 100 / total_eq;
        
        if stock_pct > 55 {
            let target_val = total_eq * 50 / 100;
            let sell_val = stock_val - target_val;
            let amount = sell_val / market.price;
            if amount > 0 {
                let ask_price = market.ask_price_0;
                if ask_price > 0 {
                    orders.submit_limit_sell(ask_price, amount);
                } else {
                    let price = market.price + my_spread;
                    orders.submit_limit_sell(price, amount);
                }
            }
        } else if stock_pct < 45 {
            let target_val = total_eq * 50 / 100;
            let buy_val = target_val - stock_val;
            let amount = buy_val / market.price;
            if amount > 0 {
                let bid_price = market.bid_price_0;
                if bid_price > 0 {
                    orders.submit_limit_buy(bid_price + 1, amount);
                } else {
                    let price = market.price - my_spread;
                    orders.submit_limit_buy(price + 1, amount);
                }
            }
        }
    }
}