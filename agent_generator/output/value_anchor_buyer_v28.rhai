let initialized = false;
let fair_value = 100_000_000;
let panic_threshold = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        fair_value = rng.rand_int(95_000_000, 105_000_000);
        panic_threshold = -rng.rand_int(10_000, 100_000);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    let current_price = market.price;
    
    if current_price < fair_value {
        let order_price = ((current_price + 500_000) / 1_000_000) * 1_000_000;
        
        let buy_amount = 0;
        if current_price < fair_value * 90 / 100 {
            buy_amount = 500;
        } else if current_price < fair_value * 95 / 100 {
            buy_amount = 100;
        }
        
        if buy_amount > 0 && account.cash > order_price * buy_amount {
            orders.submit_limit_buy(order_price, buy_amount);
        }
    }
}