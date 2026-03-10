let SPREAD = 2000;
let ORDER_SIZE = 500;
let IMBALANCE_THRESHOLD = 100;
let initialized = false;
let imbalance_sensitivity = 0;

fn on_tick() {
    if !initialized {
        imbalance_sensitivity = rng.rand_int(8, 12);
        initialized = true;
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick >= market.total_ticks * 1 / 5 {
        let pending_cnt = my_orders.pending_count();
        let i = 0;
        while i < pending_cnt {
            let oid = my_orders.pending_id(i);
            orders.submit_cancel(oid);
            i += 1;
        }
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
    let imbalance_adjust = imbalance * imbalance_sensitivity;
    
    let bid_price = mid_price - SPREAD / 2 + imbalance_adjust + 1;
    let ask_price = mid_price + SPREAD / 2 + imbalance_adjust;
    
    if bid_price > 0 {
        orders.submit_limit_buy(bid_price, ORDER_SIZE);
    }
    
    if ask_price > account.avg_cost && account.stock >= ORDER_SIZE {
        orders.submit_limit_sell(ask_price, ORDER_SIZE);
    }
}