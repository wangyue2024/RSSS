let initialized = false;
let spread = 0;
let shift_sensitivity = 0;
let min_order_size = 0;
let max_position = 0;
let last_imbalance = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        spread = rng.rand_int(1000, 5000);
        shift_sensitivity = rng.rand_int(2000, 10000);
        min_order_size = rng.rand_int(10, 100);
        max_position = rng.rand_int(500, 2000);
        last_imbalance = 0;
    }
    
    if !market.trading_enabled { return; }
    
    let pending = my_orders.pending_count();
    let i = 0;
    while i < pending {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let imbalance = market.order_imbalance;
    let price_shift = (imbalance * shift_sensitivity) / 100;
    
    let mid_price;
    if market.bid_price_0 > 0 && market.ask_price_0 > 0 {
        mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    } else {
        mid_price = market.price;
    }
    
    let adjusted_mid = mid_price + price_shift;
    let bid_price = adjusted_mid - spread / 2;
    let ask_price = adjusted_mid + spread / 2;
    
    let buy_amount = min_order_size + rng.rand_int(0, min_order_size * 2);
    let sell_amount = min_order_size + rng.rand_int(0, min_order_size * 2);
    
    if bid_price > 0 && account.stock < max_position && account.cash >= bid_price * buy_amount {
        orders.submit_limit_buy(bid_price, buy_amount);
    }
    
    let avg_cost = account.avg_cost;
    if ask_price > avg_cost && ask_price > 0 && account.stock >= sell_amount {
        orders.submit_limit_sell(ask_price, sell_amount);
    }
    
    last_imbalance = imbalance;
}