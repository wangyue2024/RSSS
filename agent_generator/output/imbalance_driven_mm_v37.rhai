let initialized = false;
let base_spread = 0;
let imbalance_sensitivity = 0;
let order_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(50_000, 150_000);
        imbalance_sensitivity = rng.rand_int(100_000, 300_000);
        order_size = rng.rand_int(50, 150);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.bid_price_0 == 0 || market.ask_price_0 == 0 {
        return;
    }
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let imbalance = market.order_imbalance;
    
    let adjustment = imbalance * imbalance_sensitivity / 1_000_000;
    let adjusted_mid = mid_price + adjustment;
    
    let raw_bid = adjusted_mid - base_spread / 2;
    let raw_ask = adjusted_mid + base_spread / 2;
    
    let rounding = 1_000_000;
    let half_round = 500_000;
    
    let rounded_bid = (raw_bid + half_round) / rounding * rounding;
    let rounded_ask = (raw_ask + half_round) / rounding * rounding;
    
    let final_bid = rounded_bid + 1;
    let final_ask = rounded_ask;
    
    if final_bid > 0 && final_bid < final_ask {
        orders.submit_limit_buy(final_bid, order_size);
    }
    
    if final_ask > 0 {
        orders.submit_limit_sell(final_ask, order_size);
    }
}