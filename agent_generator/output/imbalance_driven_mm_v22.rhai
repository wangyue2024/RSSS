let initialized = false;
let imbalance_buffer = [];

fn on_tick() {
    if !initialized {
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    imbalance_buffer.push(market.order_imbalance);
    if imbalance_buffer.len() > 5 {
        imbalance_buffer.remove(0);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if imbalance_buffer.len() < 5 { return; }
    let old_imbalance = imbalance_buffer[0];
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let base_spread = 2000;
    let imbalance_factor = 50;
    
    let adjustment = old_imbalance * imbalance_factor / 1000;
    let clamped_adj = clamp_val(adjustment, -5000, 5000);
    let adjusted_mid = mid_price + clamped_adj;
    
    let bid_price = adjusted_mid - base_spread;
    let ask_price = adjusted_mid + base_spread;
    
    if bid_price > 0 && bid_price < ask_price {
        orders.submit_limit_buy(bid_price, 100);
    }
    if ask_price > 0 && ask_price > bid_price {
        orders.submit_limit_sell(ask_price, 100);
    }
}