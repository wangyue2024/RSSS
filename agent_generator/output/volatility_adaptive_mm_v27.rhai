let initialized = false;
let base_spread = 2000;
let volatility_multiplier = 3000;
let order_amount = 100;
let my_bid_id = 0;
let my_ask_id = 0;
let bid_placed_tick = 0;
let ask_placed_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(1500, 3000);
        volatility_multiplier = rng.rand_int(2000, 4000);
        order_amount = rng.rand_int(80, 150);
    }
    
    if !market.trading_enabled { return; }
    
    let current_tick = market.tick;
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        let placed_tick = my_orders.pending_placed_tick(i);
        if current_tick - placed_tick > 3 {
            orders.submit_cancel(oid);
        }
        i += 1;
    }
    
    if current_tick % 50 != 0 { return; }
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let vol_spread = (market.std_dev * volatility_multiplier) / 10000;
    let total_spread = base_spread + vol_spread;
    
    let bid_price = mid_price - total_spread / 2;
    let ask_price = mid_price + total_spread / 2;
    
    my_bid_id = orders.submit_limit_buy(bid_price, order_amount);
    my_ask_id = orders.submit_limit_sell(ask_price, order_amount);
    
    bid_placed_tick = current_tick;
    ask_placed_tick = current_tick;
}