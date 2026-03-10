let price_history = [];
let imbalance_history = [];
let initialized = false;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
    }
    
    let current_price = market.price;
    let current_imbalance = market.order_imbalance;
    
    price_history.push(current_price);
    imbalance_history.push(current_imbalance);
    
    if price_history.len() > 6 {
        price_history.remove(0);
    }
    if imbalance_history.len() > 6 {
        imbalance_history.remove(0);
    }
    
    let fomo_window = 2;
    if price_history.len() >= fomo_window + 1 {
        let old_price = price_history[price_history.len() - fomo_window - 1];
        let price_change = (current_price - old_price) * 10000;
        if price_change > old_price * 200 || price_change < old_price * -200 {
            orders.submit_market_buy(100);
            return;
        }
    }
    
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    if price_history.len() < 6 {
        return;
    }
    
    let delayed_price = price_history[0];
    let delayed_imbalance = imbalance_history[0];
    
    let spread = delayed_price * 10 / 10000;
    let half_spread = spread / 2;
    
    let adjustment_factor = 100;
    let adjustment = (delayed_imbalance * adjustment_factor) / 10000;
    
    let bid_price = delayed_price - half_spread + adjustment + 1;
    let ask_price = delayed_price + half_spread + adjustment;
    
    let order_size = 100;
    
    orders.submit_limit_buy(bid_price, order_size);
    orders.submit_limit_sell(ask_price, order_size);
}