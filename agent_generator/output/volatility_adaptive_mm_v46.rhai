let initialized = false;
let last_prices = [];
let decision_tick = 0;
let base_spread = 8000;
let volatility_factor = 100;
let order_size = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        decision_tick = rng.rand_int(0, 49);
    }
    
    if !market.trading_enabled { return; }
    
    last_prices.push(market.price);
    if last_prices.len() > 5 {
        last_prices.remove(0);
    }
    
    if market.tick % 50 != decision_tick { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if last_prices.len() < 5 { return; }
    
    let old_price = last_prices[0];
    let volatility = market.std_dev;
    
    let spread_adjustment = (volatility * volatility_factor) / 10000;
    let total_spread = base_spread + spread_adjustment;
    let half_spread = total_spread / 2;
    
    let buy_price = old_price - half_spread;
    let sell_price = old_price + half_spread;
    
    if account.cash >= buy_price * order_size {
        orders.submit_limit_buy(buy_price, order_size);
    }
    
    if account.stock >= order_size {
        orders.submit_limit_sell(sell_price, order_size);
    }
}