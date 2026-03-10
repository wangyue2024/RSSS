let initialized = false;
let imbalance_history = [];
let price_history = [];
let base_spread = 5000;
let order_size = 10;
let adjustment_factor = 10;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = 3000 + rng.rand_int(0, 4000);
        order_size = 5 + rng.rand_int(0, 15);
        adjustment_factor = 5 + rng.rand_int(0, 10);
    }
    
    if !market.trading_enabled { return; }
    
    imbalance_history.push(market.order_imbalance);
    price_history.push(market.price);
    
    if imbalance_history.len() > 20 {
        imbalance_history.remove(0);
        price_history.remove(0);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if imbalance_history.len() < 5 {
        return;
    }
    
    let idx = imbalance_history.len() - 5;
    let old_imbalance = imbalance_history[idx];
    let old_price = price_history[idx];
    
    let imbalance_adjust = old_imbalance * adjustment_factor;
    let adjusted_mid = old_price + imbalance_adjust;
    
    let bid_price = adjusted_mid - base_spread / 2;
    let ask_price = adjusted_mid + base_spread / 2;
    
    if bid_price > 0 && account.cash >= bid_price * order_size {
        orders.submit_limit_buy(bid_price, order_size);
    }
    
    if ask_price > account.avg_cost && account.stock >= order_size {
        orders.submit_limit_sell(ask_price, order_size);
    }
}