let initialized = false;
let price_buffer = [];

fn on_tick() {
    if !market.trading_enabled { return; }
    
    if !initialized {
        initialized = true;
        for i in range(0, 5) {
            price_buffer.push(market.price);
        }
    }
    
    price_buffer.push(market.price);
    if price_buffer.len() > 5 {
        price_buffer.remove(0);
    }
    
    if market.tick % 50 != 0 { return; }
    
    let delayed_price = price_buffer[0];
    
    if rng.rand_int(0, 9999) == 0 {
        let fat_amount = 10000;
        if rng.rand_bool(50) {
            orders.submit_market_buy(fat_amount);
        } else {
            orders.submit_market_sell(fat_amount);
        }
    }
}