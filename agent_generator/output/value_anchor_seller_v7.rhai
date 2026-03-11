let initialized = false;
let fair_value = 0;
let panic_threshold = 0;
let recent_prices = [];
let cancel_threshold = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
        let base_fair_value = 100_000_000;
        let random_offset = rng.rand_int(-2_000_000, 2_000_000);
        fair_value = base_fair_value + random_offset;
        panic_threshold = rng.rand_int(-10_000_000, -1_000_000);
    }
    
    if !market.trading_enabled { return; }
    
    recent_prices.push(market.price);
    if recent_prices.len() > 5 {
        recent_prices.remove(0);
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let placed_tick = my_orders.pending_placed_tick(i);
        if market.tick - placed_tick > cancel_threshold {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if account.unrealized_pnl < panic_threshold && account.stock > 0 {
        orders.submit_market_sell(account.stock);
        return;
    }
    
    if recent_prices.len() >= 2 {
        let current = recent_prices[recent_prices.len() - 1];
        let recent = recent_prices[0];
        if current * 100 > recent * 102 {
            let buy_amount = 10;
            orders.submit_market_buy(buy_amount);
            return;
        }
    }
    
    if market.price > fair_value {
        let sell_amount = 0;
        if market.price * 100 > fair_value * 110 {
            sell_amount = account.stock * 30 / 100;
        } else if market.price * 100 > fair_value * 105 {
            sell_amount = account.stock * 10 / 100;
        }
        
        if sell_amount > 0 {
            orders.submit_limit_sell(market.price, sell_amount);
        }
    }
}