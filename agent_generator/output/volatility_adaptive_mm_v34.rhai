let price_history = [];
let initialized = false;
let base_spread_bps = 150;
let vol_sensitivity = 80;
let order_size = 500;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread_bps = rng.rand_int(120, 180);
        vol_sensitivity = rng.rand_int(60, 100);
        order_size = rng.rand_int(300, 700);
    }
    
    if !market.trading_enabled { return; }
    
    price_history.push(market.price);
    if price_history.len() > 5 {
        price_history.remove(0);
    }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if price_history.len() < 5 { return; }
    
    let delayed_price = price_history[0];
    let vol_factor = market.std_dev * vol_sensitivity / 1_000_000;
    let total_spread_bps = base_spread_bps + vol_factor;
    
    let half_spread = delayed_price * total_spread_bps / (2 * 10000);
    let bid_price = delayed_price - half_spread;
    let ask_price = delayed_price + half_spread;
    
    if bid_price > 0 && bid_price < ask_price {
        orders.submit_limit_buy(bid_price, order_size);
    }
    if ask_price > 0 && ask_price > bid_price {
        orders.submit_limit_sell(ask_price, order_size);
    }
}