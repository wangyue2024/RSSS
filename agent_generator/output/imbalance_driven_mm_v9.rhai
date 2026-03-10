let initialized = false;
let base_spread = 0;
let imbalance_threshold = 0;
let lot_percent = 0;
let skew_factor = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(20000, 80000);
        imbalance_threshold = rng.rand_int(15000, 30000);
        lot_percent = rng.rand_int(25, 50);
        skew_factor = rng.rand_int(5000, 25000);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks * 20 / 100 {
        return;
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let imbalance = market.order_imbalance;
    
    let mid_price = market.price;
    let adjustment = imbalance * skew_factor / 10000;
    let adjusted_mid = mid_price + adjustment;
    
    let bid_price = adjusted_mid - base_spread / 2;
    let ask_price = adjusted_mid + base_spread / 2;
    
    let buy_amount = account.cash * lot_percent / (100 * ask_price);
    let sell_amount = account.stock * lot_percent / 100;
    
    if buy_amount > 0 && ask_price > 0 {
        orders.submit_limit_buy(ask_price, buy_amount);
    }
    
    if sell_amount > 0 && bid_price > 0 {
        orders.submit_limit_sell(bid_price, sell_amount);
    }
}