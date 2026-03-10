let initialized = false;
let imbalance_history = [];
let price_history = [];
let bid_price = 0;
let ask_price = 0;
let base_spread = 50;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(30, 70);
    }
    
    if !market.trading_enabled {
        return;
    }
    
    imbalance_history.push(market.order_imbalance);
    price_history.push(market.price);
    
    if imbalance_history.len() > 5 {
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
    
    if price_history.len() < 5 {
        return;
    }
    
    let old_imbalance = imbalance_history[0];
    let old_price = price_history[0];
    
    let shift = clamp_val(old_imbalance, -200, 200);
    
    let half_spread = base_spread / 2;
    bid_price = old_price - half_spread + shift + 1;
    ask_price = old_price + half_spread + shift;
    
    bid_price = clamp_val(bid_price, 1, 1_000_000_000);
    ask_price = clamp_val(ask_price, 1, 1_000_000_000);
    
    if bid_price < ask_price {
        let order_amount = 100;
        
        let buy_cost = bid_price * order_amount;
        if buy_cost <= account.cash {
            orders.submit_limit_buy(bid_price, order_amount);
        }
        
        if account.stock >= order_amount {
            orders.submit_limit_sell(ask_price, order_amount);
        }
    }
}