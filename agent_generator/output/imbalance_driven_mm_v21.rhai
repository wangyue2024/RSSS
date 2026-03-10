let initialized = false;
let order_amount = 100;
let fixed_spread = 2000;
let imbalance_scale = 50;

fn on_tick() {
    if !initialized {
        initialized = true;
        order_amount = rng.rand_int(80, 120);
        fixed_spread = rng.rand_int(1500, 3000);
        imbalance_scale = rng.rand_int(30, 80);
    }
    
    if !market.trading_enabled { return; }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        orders.submit_cancel(my_orders.pending_id(i));
        i += 1;
    }
    
    let base_price = market.price;
    let imbalance = market.order_imbalance;
    let shift = imbalance * imbalance_scale / 100;
    
    let half_spread = fixed_spread / 2;
    let raw_bid = base_price + shift - half_spread;
    let bid_price = raw_bid + 1;
    let ask_price = base_price + shift + half_spread;
    
    if bid_price > 0 && account.cash >= bid_price * order_amount {
        orders.submit_limit_buy(bid_price, order_amount);
    }
    
    if ask_price > account.avg_cost && account.stock >= order_amount {
        orders.submit_limit_sell(ask_price, order_amount);
    }
}