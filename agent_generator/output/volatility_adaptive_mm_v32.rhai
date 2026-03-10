let initialized = false;
let base_spread_micros = 5000;
let spread_volatility_factor = 10;
let order_size = 100;

fn on_tick() {
    if !initialized {
        initialized = true;
        order_size = rng.rand_int(50, 200);
    }
    
    if !market.trading_enabled { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    if market.history_len() > 5 {
        let reference_price = market.history_price(5);
        let volatility = market.std_dev;
        
        let dynamic_spread = base_spread_micros + volatility * spread_volatility_factor;
        let half_spread = dynamic_spread / 2;
        
        let bid_price = reference_price - half_spread;
        let ask_price = reference_price + half_spread;
        
        let my_cash = account.cash;
        let my_stock = account.stock;
        let order_value = bid_price * order_size;
        
        if my_cash >= order_value {
            orders.submit_limit_buy(bid_price, order_size);
        }
        
        if my_stock >= order_size {
            orders.submit_limit_sell(ask_price, order_size);
        }
    }
}