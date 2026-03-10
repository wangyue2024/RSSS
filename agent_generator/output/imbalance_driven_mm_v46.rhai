let initialized = false;
let spread = 0;
let imbalance_threshold = 0;
let order_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread = rng.rand_int(1000, 5000);
        imbalance_threshold = rng.rand_int(2000, 8000);
        order_size = rng.rand_int(50, 200);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_count = my_orders.pending_count();
    let i = 0;
    while i < pending_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let mid_price = 0;
    if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    } else {
        mid_price = market.price;
    }
    
    let imbalance = market.order_imbalance;
    let imbalance_adj = 0;
    
    if imbalance > imbalance_threshold {
        imbalance_adj = (imbalance * spread) / 10000;
    } else if imbalance < -imbalance_threshold {
        imbalance_adj = (imbalance * spread) / 10000;
    }
    
    let adjusted_mid = mid_price + imbalance_adj;
    let bid_price = adjusted_mid - spread / 2 + 1;
    let ask_price = adjusted_mid + spread / 2;
    
    if bid_price > 0 && ask_price > 0 {
        orders.submit_limit_buy(bid_price, order_size);
        orders.submit_limit_sell(ask_price, order_size);
    }
}