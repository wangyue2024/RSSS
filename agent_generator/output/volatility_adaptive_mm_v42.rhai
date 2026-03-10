let price_history = [];
let std_dev_history = [];
let initialized = false;
let spread_factor = 0;
let base_spread = 0;
let order_amount = 0;
let decision_tick = -1;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        spread_factor = rng.rand_int(150, 300);
        base_spread = rng.rand_int(1000, 5000);
        order_amount = rng.rand_int(100, 500);
    }
    
    let current_tick = market.tick;
    
    price_history.push(market.price);
    std_dev_history.push(market.std_dev);
    
    if price_history.len() > 5 {
        price_history.remove(0);
        std_dev_history.remove(0);
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if current_tick % 50 == 0 && current_tick != decision_tick {
        decision_tick = current_tick;
        
        if price_history.len() >= 5 {
            let delayed_price = price_history[0];
            let delayed_std_dev = std_dev_history[0];
            
            let volatility_spread = (delayed_std_dev * spread_factor) / 10000;
            let total_spread = base_spread + volatility_spread;
            let half_spread = total_spread / 2;
            
            let bid_price = delayed_price - half_spread;
            let ask_price = delayed_price + half_spread;
            
            if bid_price > 0 && account.cash >= bid_price * order_amount {
                orders.submit_limit_buy(bid_price, order_amount);
            }
            
            if account.stock >= order_amount {
                orders.submit_limit_sell(ask_price, order_amount);
            }
        }
    }
}