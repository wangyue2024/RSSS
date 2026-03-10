let initialized = false;
let base_spread = 0;
let order_size = 0;
let max_inventory = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(2000, 5000);
        order_size = rng.rand_int(100, 500);
        max_inventory = rng.rand_int(5000, 15000);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick % 50 != 0 {
        return;
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let current_price = market.price;
    let imbalance = market.order_imbalance;
    
    let imbalance_factor = 0;
    if imbalance > 20 {
        imbalance_factor = 2500;
    } else if imbalance > 10 {
        imbalance_factor = 1200;
    } else if imbalance < -20 {
        imbalance_factor = -2500;
    } else if imbalance < -10 {
        imbalance_factor = -1200;
    }
    
    let mid_price = current_price + imbalance_factor;
    let bid_price = mid_price - base_spread / 2;
    let ask_price = mid_price + base_spread / 2;
    
    if bid_price > 0 && account.cash >= bid_price * order_size && account.stock < max_inventory {
        orders.submit_limit_buy(bid_price, order_size);
    }
    
    if ask_price > account.avg_cost && account.stock >= order_size {
        orders.submit_limit_sell(ask_price, order_size);
    }
}