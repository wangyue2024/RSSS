let initialized = false;
let base_spread = 0;
let order_size = 0;
let max_age = 3;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(5000, 20000);
        order_size = rng.rand_int(50, 200);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let i = 0;
    let pending_count = my_orders.pending_count();
    while i < pending_count {
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > max_age {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if market.bid_price_0 == 0 || market.ask_price_0 == 0 {
        return;
    }
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let imbalance = market.order_imbalance;
    
    let imbalance_factor = imbalance * 100 / 10000;
    let adjusted_mid = mid_price + (mid_price * imbalance_factor) / 10000;
    
    let bid_price = adjusted_mid - base_spread / 2;
    let ask_price = adjusted_mid + base_spread / 2;
    
    if bid_price > 0 && ask_price > 0 && bid_price < ask_price {
        orders.submit_limit_buy(bid_price, order_size);
        orders.submit_limit_sell(ask_price, order_size);
    }
}