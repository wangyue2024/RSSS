let price_history = [];
let std_dev_history = [];

let base_spread = 0;
let volatility_factor = 0;
let order_amount = 0;
let initialized = false;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(500, 3000);
        volatility_factor = rng.rand_int(200, 500);
        order_amount = rng.rand_int(100, 500);
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    std_dev_history.push(market.std_dev);
    
    if price_history.len() > 5 {
        price_history.remove(0);
        std_dev_history.remove(0);
    }
    
    let pending_cnt = my_orders.pending_count();
    let i = 0;
    while i < pending_cnt {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_history.len() < 5 { return; }
    
    let delayed_price = price_history[0];
    let delayed_std_dev = std_dev_history[0];
    
    let spread_adjustment = (volatility_factor * delayed_std_dev) / 1_000_000;
    let total_spread = base_spread + spread_adjustment;
    total_spread = clamp_val(total_spread, 100, 10000);
    
    let half_spread = total_spread / 2;
    let bid_price = delayed_price - half_spread;
    let ask_price = delayed_price + half_spread;
    
    if bid_price > 0 {
        orders.submit_limit_buy(bid_price, order_amount);
    }
    if ask_price > 0 {
        orders.submit_limit_sell(ask_price, order_amount);
    }
}