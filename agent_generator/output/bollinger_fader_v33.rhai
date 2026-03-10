let initialized = false;
let lot_size = 0;
let price_buffer = [];
let last_action_tick = 0;

fn on_tick() {
    if !initialized {
        initialized = true;
        
        let max_shares = (account.total_equity * 5 / 100) / market.price;
        if max_shares < 1 {
            lot_size = 1;
        } else {
            lot_size = rng.rand_int(1, max_shares);
        }
        
        last_action_tick = market.tick;
    }
    
    if !market.trading_enabled { return; }
    
    let cancel_count = my_orders.pending_count();
    let i = 0;
    while i < cancel_count {
        let oid = my_orders.pending_id(i);
        orders.submit_cancel(oid);
        i += 1;
    }
    
    price_buffer.push(market.price);
    if price_buffer.len() > 10 {
        price_buffer.remove(0);
    }
    
    if price_buffer.len() < 6 {
        return;
    }
    
    let old_price = price_buffer[price_buffer.len() - 6];
    let recent_price = price_buffer[price_buffer.len() - 1];
    
    let price_change = (recent_price - old_price) * 10000 / old_price;
    if price_change > 200 || price_change < -200 {
        if market.buy_volume > market.sell_volume * 3 / 2 {
            orders.submit_market_buy(lot_size);
            last_action_tick = market.tick;
        }
        return;
    }
    
    if market.tick < last_action_tick + 5 {
        return;
    }
    
    if market.std_dev * 10000 / market.price > 300 {
        return;
    }
    
    let lower_band = market.ma_20 - 2 * market.std_dev;
    let upper_band = market.ma_20 + 2 * market.std_dev;
    
    if old_price < lower_band * 105 / 100 && old_price > lower_band * 95 / 100 {
        orders.submit_limit_buy(lower_band, lot_size);
        last_action_tick = market.tick;
    }
    
    if old_price > upper_band * 95 / 100 && old_price < upper_band * 105 / 100 {
        orders.submit_limit_sell(upper_band, lot_size);
        last_action_tick = market.tick;
    }
}