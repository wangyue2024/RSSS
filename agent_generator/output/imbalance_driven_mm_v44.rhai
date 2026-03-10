let initialized = false;
let price_history = [];
let imbalance_history = [];
let DELAY_TICKS = 5;

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        price_history.clear();
        imbalance_history.clear();
    }

    let current_price = market.price;
    let current_imbalance = market.order_imbalance;
    
    price_history.push(current_price);
    imbalance_history.push(current_imbalance);
    
    if price_history.len() > DELAY_TICKS {
        price_history.remove(0);
        imbalance_history.remove(0);
    }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_history.len() < DELAY_TICKS {
        return;
    }
    
    let delayed_imbalance = imbalance_history[0];
    let imbalance_adjustment = delayed_imbalance * 10;
    
    let mid_price = price_history[0];
    let adjusted_mid = mid_price + imbalance_adjustment;
    
    let half_spread = 50000;
    let bid_price = adjusted_mid - half_spread;
    let ask_price = adjusted_mid + half_spread;
    
    if bid_price > 0 {
        let bid_amount = 1000;
        orders.submit_limit_buy(bid_price, bid_amount);
    }
    
    let ask_amount = 1000;
    orders.submit_limit_sell(ask_price, ask_amount);
}