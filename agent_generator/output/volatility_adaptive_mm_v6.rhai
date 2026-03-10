let initialized = false;
let base_spread = 0;
let order_size = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        base_spread = rng.rand_int(800, 2000);
        order_size = rng.rand_int(80, 200);
    }
    
    if !market.trading_enabled { return; }
    
    if market.tick % 50 != 0 { return; }
    
    let count = my_orders.pending_count();
    let i = 0;
    while i < count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    let mid_price = (market.bid_price_0 + market.ask_price_0) / 2;
    let volatility = market.std_dev;
    
    let spread_factor = 500 + (volatility * 15 / 100);
    let total_spread = clamp_val(spread_factor, 500, 5000);
    
    let buy_price = mid_price - total_spread / 2;
    let sell_price = mid_price + total_spread / 2;
    
    if buy_price > 0 && market.bid_price_0 > 0 {
        orders.submit_limit_buy(buy_price, order_size);
    }
    
    if sell_price > buy_price && market.ask_price_0 > 0 {
        orders.submit_limit_sell(sell_price, order_size);
    }
}